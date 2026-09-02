import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../core/assistant/anthropic_client.dart';
import '../../core/assistant/assistant_chat_controller.dart';
import '../../core/assistant/assistant_config_controller.dart';
import '../../core/assistant/assistant_models.dart';
import '../../core/assistant/document_text_extractor.dart';
import '../../core/assistant/google_ai_client.dart';
import '../../core/assistant/llm_exception.dart';
import '../../core/assistant/llm_provider.dart';
import '../../core/assistant/ollama_client.dart';
import '../../core/assistant/openai_client.dart';
import '../navigation/navigation_scope.dart';

/// Écran de chat avec l'assistant IA (Ollama local, ou un fournisseur cloud
/// connecté via une clé API — voir [LlmProvider]).
///
/// L'utilisateur pose des questions sur son patrimoine, ses simulations ou
/// sa stratégie ; le modèle répond en streaming. La logique de conversation
/// (messages, streaming, annulation) vit dans [AssistantChatController] au
/// niveau de l'app : naviguer vers une autre page ne coupe pas une réponse
/// en cours — elle continue en arrière-plan et un signal prévient à la fin.
/// Les envois parallèles sont autorisés (plusieurs questions en même temps).
///
/// Aucune donnée ne sort de la machine avec Ollama ; avec un fournisseur
/// cloud, la conversation est envoyée à ses serveurs (voir l'avertissement
/// dans les Réglages).
class AssistantScreen extends StatefulWidget {
  final AssistantConfigController configController;
  final AssistantChatController chatController;

  const AssistantScreen({
    super.key,
    required this.configController,
    required this.chatController,
  });

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

/// Mini-tutoriel affiché quand aucun modèle n'est disponible : Ollama n'est
/// peut-être pas encore installé, ou aucun modèle n'a été téléchargé.
const _modelSetupHelp =
    'Pour activer l\'assistant : installe Ollama depuis ollama.com et '
    'lance-le, puis exécute « ollama pull llama3.2 » dans un terminal, '
    'et clique sur Actualiser.';

/// Dimensions du menu déroulant du sélecteur de modèle. Le panneau de la
/// lib (SelectPopup.builder) ne se replie pas sur son contenu (`shrinkWrap`
/// est forcé à `false`) : on calcule donc une hauteur maximale cohérente
/// avec le nombre de modèles — courte si la liste est courte, plafonnée si
/// elle est longue — au lieu de le laisser s'étaler sur tout l'écran.
const _popupItemHeight = 36.0;
const _popupFixedHeight = 54.0; // champ de recherche + séparateur + paddings
const _popupMaxHeight = 240.0;
const _popupMaxWidth = 320.0;

class _AssistantScreenState extends State<AssistantScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  /// Défilement automatique : on ne colle plus le bas du chat que si
  /// l'utilisateur y était déjà (lire l'historique pendant qu'une réponse
  /// se génère ne doit pas faire sauter la vue).
  bool _stickToBottom = true;

  /// Détection automatique du modèle au premier affichage.
  bool _checkingModel = false;
  String? _modelStatus;

  /// Mini-tutoriel de mise en route (installer Ollama, pull un modèle)
  /// affiché sous [_modelStatus] quand aucun modèle n'est disponible.
  String? _modelHelp;

  /// Modèles disponibles sur l'instance (liste proposée par le sélecteur).
  List<String> _models = const [];

  /// Fournisseur + adresse (Ollama) ou clé API (fournisseurs cloud) au
  /// moment du dernier chargement de la liste : on ne relance pas une
  /// requête à chaque notification de configuration, seulement quand la
  /// config effective a changé (voir [_configKeyFor]).
  String? _lastFetchedConfigKey;

  /// Extraction de texte en cours (le bouton se désactive/affiche un
  /// indicateur le temps de lire un gros PDF).
  bool _attachingDocument = false;

  @override
  void initState() {
    super.initState();
    widget.configController.addListener(_onConfigChanged);
    widget.chatController.addListener(_onChatChanged);
    _scrollController.addListener(_onScrollChanged);
    // Rebuild à chaque frappe : le bouton « Envoyer » doit passer coloré
    // (activé) dès que le champ contient du texte, grisé sinon.
    _inputController.addListener(_onInputChanged);
    _ensureModel();
  }

  @override
  void dispose() {
    widget.configController.removeListener(_onConfigChanged);
    widget.chatController.removeListener(_onChatChanged);
    _scrollController
      ..removeListener(_onScrollChanged)
      ..dispose();
    _inputController
      ..removeListener(_onInputChanged)
      ..dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _onConfigChanged() {
    // Ré-activation de l'assistant ou changement d'adresse : relance la
    // détection du modèle si celui-ci n'est pas encore configuré.
    if (mounted && widget.configController.enabled) _ensureModel();
  }

  void _onChatChanged() {
    if (!mounted) return;
    setState(() {});
    if (_stickToBottom) _scrollToBottom();
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _stickToBottom =
        position.maxScrollExtent - position.pixels < 48 ||
        position.maxScrollExtent == 0;
  }

  /// Clé identifiant la config effective d'un fournisseur : l'adresse pour
  /// Ollama, la clé API pour les fournisseurs cloud — changer l'une ou
  /// l'autre (ou de fournisseur) invalide la dernière détection de modèles.
  String _configKeyFor(AssistantConfigController config) {
    final provider = config.provider;
    final detail = provider.isCloud
        ? config.apiKeyFor(provider)
        : config.baseUrl;
    return '${provider.name}|$detail';
  }

  Future<void> _ensureModel() async {
    final config = widget.configController;
    if (!config.enabled) return;
    // Aucun modèle encore choisi : détection automatique.
    if (config.model == null) {
      await _refreshModels();
      return;
    }
    // Modèle déjà choisi : on ne recharge la liste que si la config
    // effective a changé (fournisseur, adresse Ollama ou clé API).
    if (_lastFetchedConfigKey != _configKeyFor(config)) {
      await _refreshModels();
      return;
    }
    setState(() => _modelStatus = null);
  }

  /// Liste les modèles disponibles pour le fournisseur actif — chaque
  /// client a sa propre signature d'authentification (adresse pour Ollama,
  /// clé API pour les autres), voir `AssistantChatController._streamChat`
  /// pour le même motif de bascule côté envoi.
  Future<List<String>> _listModels(AssistantConfigController config) {
    switch (config.provider) {
      case LlmProvider.ollama:
        return OllamaClient().listModels(config.baseUrl);
      case LlmProvider.openai:
        return OpenAiClient().listModels(
          config.apiKeyFor(LlmProvider.openai)!,
        );
      case LlmProvider.anthropic:
        return AnthropicClient().listModels(
          config.apiKeyFor(LlmProvider.anthropic)!,
        );
      case LlmProvider.google:
        return GoogleAiClient().listModels(
          config.apiKeyFor(LlmProvider.google)!,
        );
    }
  }

  Future<void> _refreshModels() async {
    final config = widget.configController;
    final provider = config.provider;

    if (provider.isCloud &&
        (config.apiKeyFor(provider) == null ||
            config.apiKeyFor(provider)!.isEmpty)) {
      // Pas de clé API configurée : inutile de lancer une requête vouée à
      // l'échec, on renvoie directement vers les Réglages.
      setState(() {
        _checkingModel = false;
        _models = const [];
        _modelStatus =
            'Configure ta clé API ${provider.label} dans '
            'Réglages → Assistant IA.';
        _modelHelp = null;
      });
      _lastFetchedConfigKey = _configKeyFor(config);
      return;
    }

    setState(() {
      _checkingModel = true;
      _modelStatus = null;
      _modelHelp = null;
    });
    _lastFetchedConfigKey = _configKeyFor(config);
    try {
      final models = await _listModels(config);
      if (!mounted) return;
      setState(() {
        _models = models;
        _checkingModel = false;
      });
      if (models.isEmpty) {
        setState(() {
          _modelStatus = provider == LlmProvider.ollama
              ? 'Aucun modèle n\'est installé sur Ollama.'
              : 'Aucun modèle disponible pour cette clé ${provider.label}.';
          _modelHelp = provider == LlmProvider.ollama
              ? _modelSetupHelp
              : null;
        });
      } else if (config.model == null || !models.contains(config.model)) {
        // Aucun choix ou modèle devenu indisponible : on retombe sur le
        // premier modèle détecté, le sélecteur permet de changer ensuite.
        await config.setModel(models.first);
      } else {
        setState(() {
          _modelStatus = null;
          _modelHelp = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingModel = false;
        // Serveur/API injoignable ou clé invalide — pour Ollama, on
        // complète l'erreur par le mini-tutoriel de mise en route (souvent
        // pas encore installé/lancé) ; pour un fournisseur cloud, le
        // message d'erreur (clé invalide, quota...) suffit.
        _modelStatus = e is LlmException ? e.message : 'Erreur : $e';
        _modelHelp = provider == LlmProvider.ollama ? _modelSetupHelp : null;
      });
    }
  }

  void _send(String raw) {
    final text = raw.trim();
    if (text.isEmpty || widget.configController.model == null) return;
    _inputController.clear();
    _stickToBottom = true;
    widget.chatController.send(text);
    _scrollToBottom();
  }

  void _cancel() => widget.chatController.cancelAll();

  void _newConversation() => widget.chatController.clear();

  /// Ouvre le sélecteur de fichier, extrait le texte du document choisi
  /// (PDF avec couche texte, .txt, .md) et l'épingle à la conversation :
  /// il sera renvoyé comme contexte à chaque message suivant, jusqu'à son
  /// retrait via la croix de sa puce (voir [_buildAttachedDocumentsRow]).
  Future<void> _pickAndAttachDocument() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: supportedDocumentExtensions,
    );
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    setState(() => _attachingDocument = true);
    try {
      final extracted = await extractDocumentText(
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      widget.chatController.attachDocument(
        fileName: file.name,
        extractedText: extracted.text,
        truncated: extracted.truncated,
      );
      if (extracted.truncated) {
        _showToast(
          'Document tronqué',
          '« ${file.name} » dépasse la taille prise en charge : seul le '
              'début a été transmis à l\'assistant.',
        );
      }
    } on DocumentExtractionException catch (e) {
      if (!mounted) return;
      _showToast('Impossible de lire ce document', e.message);
    } catch (e) {
      if (!mounted) return;
      _showToast('Erreur lors de la lecture du document', '$e');
    } finally {
      if (mounted) setState(() => _attachingDocument = false);
    }
  }

  void _showToast(String title, String subtitle) {
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(title: Text(title), subtitle: Text(subtitle)),
      ),
    );
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

    final messages = widget.chatController.entries;
    return Column(
      children: [
        if (_modelStatus != null)
          _ModelStatusBanner(
            text: _modelStatus!,
            help: _modelHelp,
            loading: _checkingModel,
            onRetry: _refreshModels,
          ),
        Expanded(
          child: messages.isEmpty
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
              const Text('Assistant IA désactivé').large().medium(),
              const SizedBox(height: 8),
              Text(
                'Active l\'assistant dans les Réglages pour analyser ton '
                'patrimoine, expliquer des concepts financiers et répondre à '
                'tes questions — avec un modèle Ollama local (aucune donnée '
                'ne quitte ta machine) ou un fournisseur cloud connecté via '
                'une clé API.',
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
    final canSend = widget.configController.model != null && !_checkingModel;
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
                      onPressed: canSend ? () => _send(s) : null,
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
    final entries = widget.chatController.entries;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) => _MessageBubble(
        key: ValueKey(entries[index].id),
        entry: entries[index],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final config = widget.configController;
    final chat = widget.chatController;
    final canSend = config.model != null && !_checkingModel;
    final busy = chat.busy;
    final hasMessages = chat.entries.isNotEmpty;
    final attachedDocuments = chat.attachedDocuments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'Plusieurs réponses en cours de génération…',
              ).small().muted(),
            ),
          if (attachedDocuments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAttachedDocumentsRow(context, attachedDocuments),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Historiquement en haut de la page, l'action « Nouvelle
              // conversation » vit maintenant dans la barre de saisie.
              if (hasMessages && !busy) ...[
                Tooltip(
                  // ignore: implicit_call_tearoffs
                  tooltip: TooltipContainer(
                    child: Text('Nouvelle conversation'),
                  ),
                  child: IconButton.ghost(
                    icon: const Icon(LucideIcons.trash2),
                    onPressed: _newConversation,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Tooltip(
                // ignore: implicit_call_tearoffs
                tooltip: TooltipContainer(
                  child: Text(
                    'Joindre un document (PDF, TXT, MD)',
                  ),
                ),
                child: _attachingDocument
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton.ghost(
                        icon: const Icon(LucideIcons.paperclip),
                        onPressed: canSend ? _pickAndAttachDocument : null,
                      ),
              ),
              const SizedBox(width: 8),
              _buildModelSelector(context),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: canSend,
                  placeholder: Text(
                    canSend
                        ? 'Pose une question sur ton patrimoine…'
                        : 'Choisis d\'abord un modèle',
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
              if (busy)
                Tooltip(
                  // ignore: implicit_call_tearoffs
                  tooltip: TooltipContainer(
                    child: Text('Arrêter la génération'),
                  ),
                  child: IconButton.ghost(
                    icon: const Icon(LucideIcons.circleStop),
                    onPressed: _cancel,
                  ),
                )
              else
                PrimaryButton(
                  onPressed: canSend && _inputController.text.trim().isNotEmpty
                      ? () => _send(_inputController.text)
                      : null,
                  leading: const Icon(LucideIcons.send),
                  child: const Text('Envoyer'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Puces des documents épinglés à la conversation : chacune se retire
  /// individuellement (croix), sans passer par « Nouvelle conversation ».
  Widget _buildAttachedDocumentsRow(
    BuildContext context,
    List<AttachedDocument> documents,
  ) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final doc in documents)
          Container(
            padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.fileText,
                  size: 13,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    doc.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ).small(),
                ),
                if (doc.truncated) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    // ignore: implicit_call_tearoffs
                    tooltip: TooltipContainer(
                      child: Text(
                        'Document tronqué : seul le début a été transmis '
                        'à l\'assistant.',
                      ),
                    ),
                    child: Icon(
                      LucideIcons.triangleAlert,
                      size: 12,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
                IconButton.ghost(
                  size: ButtonSize.xSmall,
                  icon: const Icon(LucideIcons.x, size: 12),
                  onPressed: () =>
                      widget.chatController.removeAttachedDocument(doc.id),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Sélecteur du modèle, placé à côté du champ de saisie : pendant la
  /// détection on affiche un indicateur, et en l'absence de modèle détecté un
  /// bouton d'actualisation (le bandeau d'état porte alors le message).
  Widget _buildModelSelector(BuildContext context) {
    final config = widget.configController;
    if (_checkingModel) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_models.isEmpty) {
      return Tooltip(
        // ignore: implicit_call_tearoffs
        tooltip: TooltipContainer(child: Text('Actualiser la liste')),
        child: IconButton.ghost(
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          onPressed: _refreshModels,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Select<String>(
        value: config.model,
        placeholder: const Text('Modèle'),
        // Le panneau fait au moins la largeur du sélecteur, et sa largeur
        // maximale est plafonnée à une taille intermédiaire (voir
        // [popupConstraints]) : plus large que le champ, sans s'étaler sur
        // tout l'écran.
        popupWidthConstraint: PopoverConstraint.anchorMinSize,
        // Taille intermédiaire du menu : largeur plafonnée pour laisser
        // respirer les noms de modèle longs, hauteur plafonnée selon la
        // liste de modèles disponibles (courte liste = menu court).
        popupConstraints: BoxConstraints(
          maxWidth: _popupMaxWidth,
          maxHeight: math.min(
            _popupMaxHeight,
            _popupFixedHeight + _models.length * _popupItemHeight,
          ),
        ),
        onChanged: (model) {
          if (model != null) config.setModel(model);
        },
        itemBuilder: (context, model) => Text(model),
        // ignore: implicit_call_tearoffs
        popup: SelectPopup.builder(
          builder: (context, searchQuery) => SelectItemList(
            children: [
              for (final model in _models)
                if (searchQuery == null ||
                    model.toLowerCase().contains(searchQuery.toLowerCase()))
                  SelectItemButton(
                    value: model,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.brain, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'état du modèle (détection, connexion...) avec bouton de
/// nouvelle tentative en cas d'erreur. [help] affiche une marche à suivre
/// (tutoriel de mise en route) quand aucun modèle n'est disponible.
class _ModelStatusBanner extends StatelessWidget {
  final String text;
  final String? help;
  final bool loading;
  final VoidCallback onRetry;

  const _ModelStatusBanner({
    required this.text,
    this.help,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text).small().medium(),
                if (help != null) ...[
                  const SizedBox(height: 2),
                  Text(help!).xSmall().muted(),
                ],
              ],
            ),
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
/// gauche (fond de carte). Chaque bulle porte un avatar et les réponses de
/// l'assistant sont rendues en Markdown (voir [_MemoMarkdown]).
class _MessageBubble extends StatelessWidget {
  final ChatEntry entry;

  const _MessageBubble({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = entry.role == AssistantRole.user;
    // Bulle utilisateur sobre : un aplat de la couleur primaire plein écran
    // était trop marqué — on laisse la couleur en teinte légère (comme
    // l'avatar) et le texte reprend la couleur de premier plan du thème,
    // plus lisible sur ce fond translucide.
    final isDark = theme.brightness == Brightness.dark;

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 720),
      decoration: BoxDecoration(
        color: isUser
            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.12)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: isUser ? null : Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.error != null) _buildError(context),
          if (entry.status == ChatEntryStatus.cancelled &&
              entry.content.isNotEmpty) ...[
            _buildCaption(
              context,
              icon: LucideIcons.circlePause,
              text: 'Réponse interrompue',
            ),
            const SizedBox(height: 6),
          ],
          if (isUser)
            _buildUserText(theme)
          else if (entry.streaming && entry.content.isEmpty)
            _TypingIndicator()
          else
            _MemoMarkdown(entry: entry),
          if (!isUser && entry.contextInfo != null) ...[
            const SizedBox(height: 6),
            _buildCaption(
              context,
              icon: LucideIcons.database,
              text: entry.contextInfo!,
            ),
          ],
        ],
      ),
    );

    // Rangée avatar + bulle : l'avatar de l'assistant précède sa bulle,
    // celui de l'utilisateur la suit (sens de lecture naturel du chat).
    final avatar = _Avatar(isUser: isUser);
    final row = isUser
        ? Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: bubble),
              const SizedBox(width: 8),
              avatar,
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              avatar,
              const SizedBox(width: 8),
              Flexible(child: bubble),
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: row,
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          LucideIcons.circleAlert,
          size: 14,
          color: theme.colorScheme.destructive,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(entry.error!).small().medium()),
      ],
    );
  }

  Widget _buildCaption(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.mutedForeground),
        const SizedBox(width: 6),
        Text(text).muted().small(),
      ],
    );
  }

  Widget _buildUserText(ThemeData theme) {
    return Text(
      entry.content,
      style: TextStyle(color: theme.colorScheme.foreground, height: 1.45),
    );
  }
}

/// Petit avatar rond au bord de la bulle : « utilisateur » (icône personne)
/// ou « assistant » (icône bot).
class _Avatar extends StatelessWidget {
  final bool isUser;

  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.mutedForeground;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isUser ? 0.12 : 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? LucideIcons.user : LucideIcons.bot,
        size: 14,
        color: color,
      ),
    );
  }
}

/// Indicateur « le modèle réfléchit » : trois points qui s'animent.
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                // Chaque point rebondit en décalage (phase i/3 du cycle).
                Opacity(
                  opacity: 0.25 + 0.75 * ((t * 3 - i) % 1.0).clamp(0.0, 1.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.mutedForeground,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Rendu Markdown d'une réponse de l'assistant.
///
/// Le widget mémoïse sa sortie : pendant le streaming (un token par
/// notification du controller, donc un rebuild par token), seule la réponse
/// en cours est re-parse — les messages déjà terminés gardent leur widget
/// en cache au lieu d'être re-générés à chaque token. Le cache est invalidé
/// quand le contenu change, quand le statut change (fin de streaming) ou
/// quand le thème clair/sombre bascule.
class _MemoMarkdown extends StatefulWidget {
  final ChatEntry entry;

  const _MemoMarkdown({required this.entry});

  @override
  State<_MemoMarkdown> createState() => _MemoMarkdownState();
}

class _MemoMarkdownState extends State<_MemoMarkdown> {
  Widget? _cached;
  String? _cachedContent;
  bool _cachedStreaming = false;
  Brightness? _cachedBrightness;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final brightness = Theme.of(context).brightness;
    final changed =
        _cached == null ||
        _cachedBrightness != brightness ||
        _cachedStreaming != entry.streaming ||
        _cachedContent != entry.content;
    if (changed) {
      _cachedContent = entry.content;
      _cachedStreaming = entry.streaming;
      _cachedBrightness = brightness;
      // Curseur « tape au fur et à mesure » : ajouté à la fin du contenu
      // pendant le streaming (rendu comme un simple caractère final).
      final data = entry.content + (entry.streaming ? '▍' : '');
      _cached = MarkdownWidget(
        data: data,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        selectable: true,
        config: _assistantMarkdownConfig(context),
      );
    }
    return _cached!;
  }
}

/// Configuration de rendu Markdown adaptée au thème courant : texte dans la
/// couleur `foreground` de l'app, code en police monospace sur fond
/// `muted`, liens colorés `primary`, thème de coloration du code sombre ou
/// clair selon la luminosité.
MarkdownConfig _assistantMarkdownConfig(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final base = TextStyle(
    fontSize: 14.5,
    height: 1.45,
    color: colorScheme.foreground,
  );
  final heading = base.copyWith(fontWeight: FontWeight.w600);
  final codeBg = colorScheme.muted.withValues(alpha: isDark ? 0.35 : 0.45);
  final monospace = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 1.4,
  );

  final configs = <WidgetConfig>[
    PConfig(textStyle: base),
    H1Config(style: heading.copyWith(fontSize: 20)),
    H2Config(style: heading.copyWith(fontSize: 18)),
    H3Config(style: heading.copyWith(fontSize: 16)),
    H4Config(style: heading.copyWith(fontSize: 14.5)),
    H5Config(style: heading.copyWith(fontSize: 14.5)),
    H6Config(style: heading.copyWith(fontSize: 14.5)),
    CodeConfig(
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: codeBg,
        color: colorScheme.foreground,
      ),
    ),
    // Le thème de coloration (a11y light/dark) est celui fourni par défaut
    // par PreConfig / PreConfig.darkConfig : on n'en change que le cadre.
    isDark
        ? PreConfig.darkConfig.copy(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: codeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.border),
            ),
            textStyle: monospace,
          )
        : PreConfig(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: codeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.border),
            ),
            textStyle: monospace,
          ),
    LinkConfig(
      style: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    ),
  ];

  // En thème sombre, la base darkConfig couvre les éléments non surchargés
  // (tableaux, citations, hr, checklist...) ; en thème clair, le défaut.
  final baseConfig = isDark
      ? MarkdownConfig.darkConfig
      : MarkdownConfig.defaultConfig;
  return baseConfig.copy(configs: configs);
}
