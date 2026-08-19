import 'dart:async';

import 'package:flutter/foundation.dart';

import 'assistant_config_controller.dart';
import 'assistant_context_builder.dart';
import 'assistant_models.dart';
import 'ollama_client.dart';

/// Statut d'une entrée de conversation, côté affichage.
enum ChatEntryStatus {
  /// Réponse en cours de génération (streaming).
  streaming,

  /// Message terminé normalement.
  done,

  /// La requête a échoué ; [ChatEntry.error] porte le message à afficher.
  error,

  /// La requête a été interrompue (annulation, changement de profil/vault).
  cancelled,
}

/// Une entrée de la conversation affichée : un message utilisateur ou une
/// réponse de l'assistant.
///
/// [content] et [status] sont mutables : la même instance est affichée puis
/// mise à jour au fil du streaming (l'écran s'abonne au controller et relit
/// les entrées à chaque notification).
class ChatEntry {
  /// Identifiant stable, sert de `ValueKey` pour la réconciliation Flutter.
  final String id;

  /// `user` ou `assistant` (le rôle `system` n'est jamais affiché).
  final AssistantRole role;

  /// Texte du message : complet pour un message utilisateur, en croissance
  /// pendant le streaming d'une réponse.
  String content;

  /// Statut courant de l'entrée.
  ChatEntryStatus status;

  /// Message d'erreur à afficher (uniquement quand [status] vaut [error]).
  String? error;

  /// Diagnostic sur le contexte patrimoine envoyé pour ce tour (uniquement
  /// renseigné sur une entrée assistant) — rend visible si les données
  /// locales ont bien été transmises au modèle plutôt que de laisser deviner
  /// si une réponse qui « ne connaît pas » le patrimoine vient d'un contexte
  /// manquant/vide ou d'une limite du modèle local choisi (voir
  /// [AssistantChatController._runRequest]).
  String? contextInfo;

  ChatEntry({
    required this.id,
    required this.role,
    required this.content,
    required this.status,
    this.error,
    this.contextInfo,
  });

  bool get streaming => status == ChatEntryStatus.streaming;
}

/// Logique de la conversation avec l'assistant Ollama, indépendante de
/// l'écran : le controller vit au niveau de l'app (dans `main.dart`) et
/// survit donc à la navigation. Envoyer un message depuis la page Assistant
/// puis naviguer ailleurs ne coupe rien — la réponse continue de se générer
/// en arrière-plan, et un signal (badge sidebar + toast) prévient à la fin.
///
/// Les requêtes sont **parallèles** : plusieurs envois peuvent coexister
/// (chacun sa paire message utilisateur + réponse en streaming). Le
/// streaming est poussé via [ChangeNotifier.notifyListeners] à chaque token.
class AssistantChatController extends ChangeNotifier {
  final AssistantConfigController _config;
  final String Function() _activeDataPath;
  final OllamaClient _client;

  AssistantChatController({
    required AssistantConfigController config,
    required String Function() activeDataPath,
    OllamaClient? client,
  })  : // `config` et `activeDataPath` gardent des noms publics (le champ est
        // privé) : l'assignation directe est volontaire, pas un oubli.
        // ignore: prefer_initializing_formals
        _config = config,
        // ignore: prefer_initializing_formals
        _activeDataPath = activeDataPath,
        _client = client ?? OllamaClient();

  final List<ChatEntry> _entries = [];
  final List<Completer<void>> _pendingCancellations = [];
  int _idSequence = 0;

  /// Compteur de réponses terminées pendant que l'écran assistant n'était
  /// pas visible : c'est le « non-lu » affiché en badge sur l'item Assistant
  /// de la sidebar. `ValueNotifier` (léger) pour que l'AppShell s'y abonne
  /// sans re-rendre tout le shell à chaque token du streaming.
  final ValueNotifier<int> unreadResponses = ValueNotifier(0);

  /// Mis à `true` par l'AppShell quand la page Assistant est affichée : les
  /// réponses terminées pendant ce temps ne comptent pas comme « non lues ».
  bool assistantVisible = false;

  /// Entrées de la conversation, dans l'ordre d'affichage.
  List<ChatEntry> get entries => List.unmodifiable(_entries);

  /// Une requête est-elle en cours (au moins une réponse en streaming) ?
  bool get busy => _entries.any((e) => e.status == ChatEntryStatus.streaming);

  /// Interrompt toutes les requêtes en cours (bouton « stop », changement de
  /// profil/vault). Les réponses partielles déjà générées sont conservées
  /// avec le statut [ChatEntryStatus.cancelled].
  void cancelAll() {
    for (final cancel in _pendingCancellations) {
      if (!cancel.isCompleted) cancel.complete();
    }
    _pendingCancellations.clear();
  }

  /// Vide la conversation. Les requêtes en cours sont annulées.
  void clear() {
    cancelAll();
    _entries.clear();
    notifyListeners();
  }

  /// Envoie [raw] au modèle : ajoute immédiatement la paire (message
  /// utilisateur, réponse en streaming), puis laisse la requête tourner en
  /// arrière-plan — l'appel retourne à l'UI avant la fin de la génération.
  ///
  /// Les envois parallèles sont autorisés (pas de verrou sur [busy]) :
  /// chaque requête a son propre signal d'annulation.
  void send(String raw) {
    final text = raw.trim();
    if (text.isEmpty || _config.model == null) return;

    final userEntry = ChatEntry(
      id: _newId(),
      role: AssistantRole.user,
      content: text,
      status: ChatEntryStatus.done,
    );
    final assistantEntry = ChatEntry(
      id: _newId(),
      role: AssistantRole.assistant,
      content: '',
      status: ChatEntryStatus.streaming,
    );
    _entries.add(userEntry);
    _entries.add(assistantEntry);
    notifyListeners();

    // Chaque requête porte son propre signal d'annulation : `cancelAll`
    // les complète tous, une requête neuve démarre avec un signal vierge.
    final cancel = Completer<void>();
    _pendingCancellations.add(cancel);

    unawaited(_runRequest(userEntry, assistantEntry, cancel));
  }

  Future<void> _runRequest(
    ChatEntry userEntry,
    ChatEntry assistantEntry,
    Completer<void> cancel,
  ) async {
    final config = _config;

    // La synthèse du patrimoine est lue sur disque (async) avant l'appel
    // réseau : si la requête est annulée pendant cette lecture, on s'arrête
    // là — pas de réponse à produire pour un message annulé.
    var context = '';
    if (config.includePatrimoine) {
      try {
        context = await AssistantContextBuilder(_activeDataPath())
            .buildPatrimoineContext();
        // Sans ce diagnostic visible, une réponse qui semble ignorer le
        // patrimoine était indiscernable entre "le contexte n'est jamais
        // arrivé jusqu'au modèle" (bug à corriger) et "le modèle local
        // choisi ne l'exploite pas bien" (limite du modèle) — voir
        // `assistant_screen.dart`'s `_MessageBubble`.
        assistantEntry.contextInfo = context.trim().isEmpty
            ? 'Contexte patrimoine : aucune donnée trouvée pour ce profil.'
            : 'Contexte patrimoine inclus (${context.length} caractères).';
      } catch (e) {
        // Le contexte reste vide (le modèle répond sur la seule question),
        // mais l'échec n'est plus invisible.
        assistantEntry.contextInfo =
            'Contexte patrimoine : échec du chargement ($e).';
      }
    } else {
      assistantEntry.contextInfo =
          'Contexte patrimoine désactivé (Réglages → Assistant IA).';
    }
    if (cancel.isCompleted) {
      assistantEntry
        ..content = ''
        ..status = ChatEntryStatus.cancelled;
      _pendingCancellations.remove(cancel);
      notifyListeners();
      return;
    }

    try {
      final response = await _client.streamChat(
        baseUrl: config.baseUrl,
        model: config.model!,
        messages: _buildPayload(context: context),
        onToken: (partial) {
          // Si l'annulation arrive entre deux lignes du flux, on arrête
          // d'accumuler : l'état final est posé plus bas dans le `finally`.
          if (cancel.isCompleted) return;
          assistantEntry.content += partial;
          notifyListeners();
        },
        isCancelled: () => cancel.isCompleted,
      );

      if (cancel.isCompleted) {
        assistantEntry.status = ChatEntryStatus.cancelled;
      } else {
        assistantEntry.content = response;
        assistantEntry.status = ChatEntryStatus.done;
        _markResponseCompleted();
      }
    } on OllamaException catch (e) {
      if (cancel.isCompleted) {
        assistantEntry.status = ChatEntryStatus.cancelled;
      } else {
        assistantEntry.status = ChatEntryStatus.error;
        assistantEntry.error = e.message;
      }
    } catch (e) {
      if (cancel.isCompleted) {
        assistantEntry.status = ChatEntryStatus.cancelled;
      } else {
        assistantEntry.status = ChatEntryStatus.error;
        assistantEntry.error = 'Erreur : $e';
      }
    } finally {
      _pendingCancellations.remove(cancel);
      notifyListeners();
    }
  }

  /// Une réponse vient de se terminer : elle compte comme « non lue » sauf
  /// si la page Assistant est affichée à cet instant.
  void _markResponseCompleted() {
    if (!assistantVisible) unreadResponses.value++;
  }

  /// Marque toutes les réponses comme lues (l'utilisateur ouvre l'assistant).
  void markAllRead() {
    if (unreadResponses.value != 0) unreadResponses.value = 0;
  }

  List<AssistantMessage> _buildPayload({required String context}) {
    // Seuls les échanges terminés partent au modèle : le message utilisateur
    // courant (dernier tour) et les tours utilisateur/assistant déjà clos.
    // Les réponses annulées ou en erreur sont exclues (leur question reste),
    // ainsi que les réponses encore en streaming — envoyer une réponse
    // vide en dernière position ferait arrêter le modèle prématurément.
    final history = [
      for (final e in _entries)
        if (e.role != AssistantRole.system &&
            e.status != ChatEntryStatus.cancelled &&
            e.status != ChatEntryStatus.error &&
            e.status != ChatEntryStatus.streaming)
          AssistantMessage(role: e.role, content: e.content),
    ];
    // On ne renvoie que les derniers échanges, pour borner la taille du
    // contexte (et donc la consommation mémoire/tokens) à chaque tour.
    final tail = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    return [
      AssistantMessage(
        role: AssistantRole.system,
        content: _buildSystemPrompt(context: context),
      ),
      ...tail,
    ];
  }

  String _newId() => 'c${_idSequence++}';

  /// Prompt système : règles de comportement du modèle + synthèse locale du
  /// patrimoine du profil actif quand l'option est activée.
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
      prompt.writeln(
        'Les données ci-dessous viennent directement du vault local de '
        'l\'utilisateur (comptes, budget, notes, simulations) : elles sont '
        'à jour et fiables, pas une supposition. Tu as bien accès à ces '
        'données — ne dis JAMAIS que tu n\'as pas accès aux informations '
        'financières de l\'utilisateur, ni que tu ne peux pas voir son '
        'patrimoine : réponds directement avec les chiffres ci-dessous.',
      );
      prompt.writeln();
      prompt.writeln(context);
    }
    return prompt.toString();
  }

  @override
  void dispose() {
    cancelAll();
    unreadResponses.dispose();
    super.dispose();
  }
}
