import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../core/assistant/assistant_config_controller.dart';
import '../../core/assistant/assistant_context_builder.dart';
import '../../core/assistant/assistant_models.dart';
import '../../core/assistant/ollama_client.dart';
import '../navigation/navigation_scope.dart';

/// Écran de chat avec l'assistant IA local (Ollama).
///
/// L'utilisateur pose des questions sur son patrimoine, ses simulations ou
/// sa stratégie ; le modèle répond en streaming, en s'appuyant, quand
/// l'option est activée, sur une synthèse locale des données du profil
/// (voir [AssistantContextBuilder]). Aucune donnée ne sort de la machine :
/// la conversation transite uniquement vers l'instance Ollama configurée.
class AssistantScreen extends StatefulWidget {
  final String vaultPath;
  final AssistantConfigController configController;

  const AssistantScreen({
    super.key,
    required this.vaultPath,
    required this.configController,
  });

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _client = OllamaClient();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  /// Messages terminés (utilisateur + réponses complètes). La réponse en
  /// cours de génération vit dans [_streamingText].
  final List<AssistantMessage> _messages = [];

  /// Fragment de réponse du modèle en cours de streaming.
  String _streamingText = '';
  bool _busy = false;
  bool _cancelled = false;
  String? _lastError;

  /// Détection automatique du modèle au premier affichage.
  bool _checkingModel = false;
  String? _modelStatus;

  @override
  void initState() {
    super.initState();
    widget.configController.addListener(_onConfigChanged);
    _ensureModel();
  }

  @override
  void dispose() {
    widget.configController.removeListener(_onConfigChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onConfigChanged() {
    // Ré-activation de l'assistant depuis les Réglages : relance la
    // détection du modèle si celui-ci n'est pas encore configuré.
    if (mounted && widget.configController.enabled) _ensureModel();
  }

  Future<void> _ensureModel() async {
    final config = widget.configController;
    if (!config.enabled) return;
    if (config.model != null) {
      setState(() => _modelStatus = 'Modèle : ${config.model}');
      return;
    }
    setState(() {
      _checkingModel = true;
      _modelStatus = null;
    });
    try {
      final models = await _client.listModels(config.baseUrl);
      if (models.isEmpty) {
        setState(() {
          _modelStatus =
              'Aucun modèle n\'est installé sur Ollama. Lance « ollama pull '
              'llama3.2 » dans un terminal, puis actualise.';
        });
      } else {
        await config.setModel(models.first);
        if (mounted) {
          setState(() => _modelStatus = 'Modèle sélectionné : ${models.first}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _modelStatus = e is OllamaException ? e.message : 'Erreur : $e';
        });
      }
    } finally {
      if (mounted) setState(() => _checkingModel = false);
    }
  }

  String _buildSystemPrompt({required String context}) {
    final prompt = StringBuffer(
      'Tu es l\'assistant financier d\'Opime, une application locale de '
      'gestion de patrimoine. Tu dialogues avec un utilisateur francophone.\n'
      '\n'
      'Règles :\n'
      '- Réponds toujours en français, de façon claire et pédagogique.\n'
      '- Pour toute analyse chiffrée, base-toi exclusivement sur le contexte '
      'fourni ci-dessous ; n\'invente jamais un montant, une quantité ou une '
      'performance.\n'
      '- Cite les chiffres exacts du contexte quand tu analyses le patrimoine.\n'
      '- Explique le « pourquoi » (mécanismes, implications) et pas seulement '
      'le « quoi ».\n'
      '- Tu peux analyser le patrimoine, expliquer des concepts financiers et '
      'éclairer les notes de stratégie et les simulations enregistrées.\n'
      '- Tes réponses sont informatives et ne constituent pas un conseil '
      'fiscal, juridique ou patrimonial professionnel personnalisé ; '
      'rappelle-le brièvement si la question engage ce terrain.\n'
      '- Utilise un Markdown léger (listes à puces, **gras**, tableaux '
      'simples si utiles).\n',
    );
    if (context.isNotEmpty) {
      prompt.writeln();
      prompt.writeln('## Contexte (données locales du profil actif)');
      prompt.writeln(context);
    }
    return prompt.toString();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;

    final config = widget.configController;
    setState(() {
      _inputController.clear();
      _messages.add(AssistantMessage(role: AssistantRole.user, content: text));
      _streamingText = '';
      _busy = true;
      _cancelled = false;
      _lastError = null;
    });
    _scrollToBottom();

    try {
      final context = config.includePatrimoine
          ? await AssistantContextBuilder(widget.vaultPath)
              .buildPatrimoineContext()
          : '';
      if (!mounted || !_busy) return;

      final payload = <AssistantMessage>[
        AssistantMessage(
          role: AssistantRole.system,
          content: _buildSystemPrompt(context: context),
        ),
        // On n'envoie que les derniers échanges, pour borner la taille du
        // contexte renvoyé au modèle à chaque tour.
        ..._messages.skip(_messages.length > 20 ? _messages.length - 20 : 0),
      ];

      final response = await _client.streamChat(
        baseUrl: config.baseUrl,
        model: config.model!,
        messages: payload,
        onToken: (partial) {
          if (!mounted) return;
          setState(() => _streamingText += partial);
          _scrollToBottom();
        },
        isCancelled: () => _cancelled,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          AssistantMessage(role: AssistantRole.assistant, content: response),
        );
        _streamingText = '';
        _busy = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _streamingText = '';
        _busy = false;
        _lastError = e is OllamaException ? e.message : 'Erreur : $e';
      });
    }
  }

  void _cancel() {
    setState(() => _cancelled = true);
  }

  void _newConversation() {
    setState(() {
      _messages.clear();
      _streamingText = '';
      _lastError = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.configController.enabled;
    // Pas d'en-tête propre à la page : elle est identifiée par le titre de
    // la TopBar et l'item de la sidebar. Le chat occupe toute la hauteur.
    return _buildBody(context, enabled);
  }

  Widget _buildBody(BuildContext context, bool enabled) {
    if (!enabled) return _buildDisabledState(context);

    return Column(
      children: [
        if (_modelStatus != null)
          _ModelStatusBanner(
            text: _modelStatus!,
            loading: _checkingModel,
            onRetry: _ensureModel,
          ),
        Expanded(
          child: _messages.isEmpty && _streamingText.isEmpty
              ? _buildEmptyState(context)
              : _buildMessageList(context),
        ),
        _buildInputBar(context),
      ],
    );
  }

  Widget _buildDisabledState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.bot, size: 48, color: theme.colorScheme.muted),
              const SizedBox(height: 16),
              const Text(
                'Assistant IA désactivé',
              ).large().medium(),
              const SizedBox(height: 8),
              Text(
                'Active l\'assistant dans les Réglages pour analyser ton '
                'patrimoine, expliquer des concepts financiers et répondre à '
                'tes questions — grâce à un modèle Ollama local, sans qu\'aucune '
                'donnée ne quitte ta machine.',
                textAlign: TextAlign.center,
              ).muted(),
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: () =>
                    NavigationScope.maybeOf(context)?.call('settings'),
                leading: const Icon(LucideIcons.settings),
                child: const Text('Ouvrir les Réglages'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = const [
      'Analyse mon patrimoine',
      'Explique-moi mon allocation',
      'Résume ma stratégie',
      'Que disent mes simulations ?',
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.sparkles,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text('Que veux-tu savoir ?').large().medium(),
              const SizedBox(height: 8),
              Text(
                'Pose une question sur ton patrimoine, tes simulations ou ta '
                'stratégie. Les réponses s\'appuient sur tes données locales '
                'si l\'option de contexte est activée.',
                textAlign: TextAlign.center,
              ).muted(),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in suggestions)
                    OutlineButton(
                      onPressed: _busy ? null : () => _send(s),
                      child: Text(s),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final entries = <Widget>[
      for (final message in _messages) _MessageBubble(message: message),
      if (_busy)
        _MessageBubble(
          message: AssistantMessage(
            role: AssistantRole.assistant,
            content: _streamingText,
          ),
          streaming: true,
          showError: _lastError,
        ),
    ];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: entries,
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final canSend = !_busy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Historiquement en haut de la page, l'action « Nouvelle
          // conversation » vit maintenant dans la barre de saisie.
          if (_messages.isNotEmpty && canSend) ...[
            Tooltip(
              // ignore: implicit_call_tearoffs
              tooltip: TooltipContainer(child: Text('Nouvelle conversation')),
              child: IconButton.ghost(
                icon: const Icon(LucideIcons.trash2),
                onPressed: _newConversation,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: canSend,
              placeholder: const Text(
                'Pose une question sur ton patrimoine…',
              ),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (canSend && value.trim().isNotEmpty) _send(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          if (canSend)
            PrimaryButton(
              onPressed: () => _send(_inputController.text),
              leading: const Icon(LucideIcons.send),
              child: const Text('Envoyer'),
            )
          else
            Tooltip(
              // ignore: implicit_call_tearoffs
              tooltip: TooltipContainer(child: Text('Arrêter la génération')),
              child: IconButton.ghost(
                icon: const Icon(LucideIcons.circleStop),
                onPressed: _cancel,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bandeau d'état du modèle (détection, connexion...) avec bouton de
/// nouvelle tentative en cas d'erreur.
class _ModelStatusBanner extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback onRetry;

  const _ModelStatusBanner({
    required this.text,
    required this.loading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = !loading;
    return Container(
      width: double.infinity,
      color: isError
          ? theme.colorScheme.destructive.withValues(alpha: 0.08)
          : theme.colorScheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              LucideIcons.circleAlert,
              size: 14,
              color: theme.colorScheme.destructive,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text).small().muted(),
          ),
          if (isError)
            Tooltip(
              // ignore: implicit_call_tearoffs
              tooltip: TooltipContainer(child: Text('Réessayer')),
              child: IconButton.ghost(
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                onPressed: onRetry,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bulle d'un message : utilisateur à droite (fond primaire), assistant à
/// gauche (fond de carte). En [streaming], un curseur clignotant suit le
/// texte en cours de génération.
class _MessageBubble extends StatelessWidget {
  final AssistantMessage message;
  final bool streaming;
  final String? showError;

  const _MessageBubble({
    required this.message,
    this.streaming = false,
    this.showError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == AssistantRole.user;

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 760),
      decoration: BoxDecoration(
        color: isUser
            ? theme.colorScheme.primary
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: isUser
            ? null
            : Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showError != null) ...[
            Row(
              children: [
                Icon(
                  LucideIcons.circleAlert,
                  size: 14,
                  color: theme.colorScheme.destructive,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(showError!).small().medium(),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (streaming && message.content.isEmpty)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Le modèle réfléchit…').muted().small(),
              ],
            )
          else
            Text(
              message.content + (streaming ? '▍' : ''),
              style: TextStyle(
                color: isUser
                    ? theme.colorScheme.primaryForeground
                    : theme.colorScheme.foreground,
              ),
            ),
        ],
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }
}
