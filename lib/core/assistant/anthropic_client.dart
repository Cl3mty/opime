import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'assistant_models.dart';
import 'llm_exception.dart';

/// Erreur remontée par l'API Anthropic (clé invalide, quota dépassé,
/// réponse mal formée...) — avec un message déjà prêt à afficher à
/// l'utilisateur, en français.
class AnthropicException implements LlmException {
  @override
  final String message;
  const AnthropicException(this.message);

  @override
  String toString() => message;
}

/// Client minimaliste de l'API Anthropic (`https://api.anthropic.com/v1`),
/// authentifié par clé API (voir `AssistantConfigController.apiKeyFor`) —
/// contrairement à [OllamaClient], les messages envoyés quittent la machine
/// et sont traités par les serveurs d'Anthropic.
///
/// Contrairement à Ollama/OpenAI, l'API Anthropic n'accepte pas de message
/// de rôle `system` dans la liste `messages` : elle veut le prompt système
/// dans un champ `system` séparé. [streamChat] extrait donc lui-même ce
/// message avant de construire la requête — `AssistantChatController` reste
/// agnostique du fournisseur.
class AnthropicClient {
  static const _baseUrl = 'https://api.anthropic.com/v1';
  static const _apiVersion = '2023-06-01';

  /// Anthropic exige un `max_tokens` explicite (pas de valeur par défaut
  /// côté API) : suffisant pour une réponse de chat sans borner
  /// artificiellement une explication un peu longue.
  static const _maxTokens = 4096;

  /// Client HTTP injectable pour les tests (ex : `http.testing.MockClient`) —
  /// `null` en usage normal, où chaque appel crée puis referme son propre
  /// `http.Client()`, comme [OllamaClient].
  final http.Client? _injectedClient;

  AnthropicClient({http.Client? httpClient}) : _injectedClient = httpClient;

  Map<String, String> _headers(String apiKey) => {
    'x-api-key': apiKey,
    'anthropic-version': _apiVersion,
    'Content-Type': 'application/json',
  };

  /// Liste les modèles disponibles pour cette clé, triés par ordre
  /// alphabétique. Lance [AnthropicException] si la clé est invalide ou
  /// l'API injoignable.
  Future<List<String>> listModels(String apiKey) async {
    final client = _injectedClient ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('$_baseUrl/models'), headers: _headers(apiKey))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw AnthropicException(_apiErrorMessage(response));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawModels = (decoded is Map<String, dynamic>)
          ? (decoded['data'] as List? ?? const [])
          : const [];
      final names = <String>[
        for (final m in rawModels)
          if (m is Map<String, dynamic> && (m['id'] is String))
            m['id'] as String,
      ]..sort();
      return names;
    } on SocketException {
      throw const AnthropicException(
        'Impossible de joindre l\'API Anthropic. Vérifie ta connexion réseau.',
      );
    } on FormatException {
      throw const AnthropicException('Réponse d\'Anthropic illisible.');
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  /// Dialogue en streaming avec le modèle [model]. Mêmes garanties que
  /// [OllamaClient.streamChat] (annulation propre, réponse partielle
  /// retournée si interrompu).
  Future<String> streamChat({
    required String apiKey,
    required String model,
    required List<AssistantMessage> messages,
    void Function(String partial)? onToken,
    bool Function()? isCancelled,
  }) async {
    final client = _injectedClient ?? http.Client();
    try {
      final systemPrompt = messages
          .where((m) => m.role == AssistantRole.system)
          .map((m) => m.content)
          .join('\n\n');
      final conversation = messages.where(
        (m) => m.role != AssistantRole.system,
      );

      final request = http.Request('POST', Uri.parse('$_baseUrl/messages'));
      request.headers.addAll(_headers(apiKey));
      request.body = jsonEncode({
        'model': model,
        'max_tokens': _maxTokens,
        if (systemPrompt.isNotEmpty) 'system': systemPrompt,
        'messages': [for (final m in conversation) m.toApiJson()],
        'stream': true,
      });

      final response = await client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw const AnthropicException(
          'L\'API Anthropic ne répond plus. Réessaie dans un instant.',
        ),
      );
      if (response.statusCode != 200) {
        throw AnthropicException(await _streamedErrorMessage(response));
      }

      final buffer = StringBuffer();
      await for (final line in utf8.decoder
          .bind(response.stream)
          .transform(const LineSplitter())) {
        if (isCancelled?.call() ?? false) break;
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload.isEmpty) continue;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map<String, dynamic>) continue;
          if (decoded['type'] == 'error') {
            final error = decoded['error'];
            final message = error is Map<String, dynamic>
                ? error['message']
                : null;
            throw AnthropicException(
              message is String ? message : 'Erreur Anthropic inconnue.',
            );
          }
          if (decoded['type'] != 'content_block_delta') continue;
          final delta = decoded['delta'];
          if (delta is Map<String, dynamic> &&
              delta['type'] == 'text_delta' &&
              delta['text'] is String) {
            final content = delta['text'] as String;
            if (content.isEmpty) continue;
            buffer.write(content);
            onToken?.call(content);
          }
        } on FormatException {
          // Ligne JSON incomplète (fragment coupé par le réseau) : ignorée,
          // la suite du flux la complètera.
          continue;
        }
      }
      return buffer.toString();
    } on SocketException {
      throw const AnthropicException(
        'Impossible de joindre l\'API Anthropic. Vérifie ta connexion réseau.',
      );
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  String _apiErrorMessage(http.Response response) {
    if (response.statusCode == 401) {
      return 'Clé API Anthropic invalide ou expirée.';
    }
    if (response.statusCode == 429) {
      return 'Quota Anthropic dépassé. Réessaie plus tard.';
    }
    return 'Anthropic a répondu HTTP ${response.statusCode}.';
  }

  Future<String> _streamedErrorMessage(http.StreamedResponse response) async {
    if (response.statusCode == 401) {
      return 'Clé API Anthropic invalide ou expirée.';
    }
    if (response.statusCode == 429) {
      return 'Quota Anthropic dépassé. Réessaie plus tard.';
    }
    final body = await response.stream.bytesToString();
    return 'Anthropic a répondu HTTP ${response.statusCode}'
        '${body.trim().isEmpty ? '.' : ' : ${body.trim()}'}';
  }
}
