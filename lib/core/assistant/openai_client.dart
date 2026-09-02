import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'assistant_models.dart';
import 'llm_exception.dart';

/// Erreur remontée par l'API OpenAI (clé invalide, quota dépassé, réponse
/// mal formée...) — avec un message déjà prêt à afficher à l'utilisateur,
/// en français.
class OpenAiException implements LlmException {
  @override
  final String message;
  const OpenAiException(this.message);

  @override
  String toString() => message;
}

/// Client minimaliste de l'API OpenAI (`https://api.openai.com/v1`),
/// authentifié par clé API (voir `AssistantConfigController.apiKeyFor`) —
/// contrairement à [OllamaClient], les messages envoyés quittent la machine
/// et sont traités par les serveurs d'OpenAI.
///
/// Mêmes deux appels que [OllamaClient] : [listModels] et [streamChat].
class OpenAiClient {
  static const _baseUrl = 'https://api.openai.com/v1';

  /// Client HTTP injectable pour les tests (ex : `http.testing.MockClient`) —
  /// `null` en usage normal, où chaque appel crée puis referme son propre
  /// `http.Client()`, comme [OllamaClient].
  final http.Client? _injectedClient;

  OpenAiClient({http.Client? httpClient}) : _injectedClient = httpClient;

  /// Modèles de complétion de texte exclus de [listModels] : embeddings,
  /// audio, images, modération... ne servent pas à un chat conversationnel.
  static final _excludedModelPattern = RegExp(
    r'embedding|whisper|tts|dall-e|moderation|audio|realtime|davinci|babbage|instruct',
    caseSensitive: false,
  );

  Map<String, String> _headers(String apiKey) => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  /// Liste les modèles de chat disponibles pour cette clé, triés par ordre
  /// alphabétique. Lance [OpenAiException] si la clé est invalide ou
  /// l'API injoignable.
  Future<List<String>> listModels(String apiKey) async {
    final client = _injectedClient ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('$_baseUrl/models'), headers: _headers(apiKey))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw OpenAiException(_apiErrorMessage(response));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawModels = (decoded is Map<String, dynamic>)
          ? (decoded['data'] as List? ?? const [])
          : const [];
      final names = <String>[
        for (final m in rawModels)
          if (m is Map<String, dynamic> && (m['id'] is String))
            m['id'] as String,
      ]..retainWhere((id) => !_excludedModelPattern.hasMatch(id));
      names.sort();
      return names;
    } on SocketException {
      throw const OpenAiException(
        'Impossible de joindre l\'API OpenAI. Vérifie ta connexion réseau.',
      );
    } on FormatException {
      throw const OpenAiException('Réponse d\'OpenAI illisible.');
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
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/chat/completions'),
      );
      request.headers.addAll(_headers(apiKey));
      request.body = jsonEncode({
        'model': model,
        'messages': [for (final m in messages) m.toApiJson()],
        'stream': true,
      });

      final response = await client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw const OpenAiException(
          'L\'API OpenAI ne répond plus. Réessaie dans un instant.',
        ),
      );
      if (response.statusCode != 200) {
        throw OpenAiException(await _streamedErrorMessage(response));
      }

      final buffer = StringBuffer();
      await for (final line in utf8.decoder
          .bind(response.stream)
          .transform(const LineSplitter())) {
        if (isCancelled?.call() ?? false) break;
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload == '[DONE]') break;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map<String, dynamic>) continue;
          final choices = decoded['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = choices.first['delta'];
          if (delta is Map<String, dynamic> && delta['content'] is String) {
            final content = delta['content'] as String;
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
      throw const OpenAiException(
        'Impossible de joindre l\'API OpenAI. Vérifie ta connexion réseau.',
      );
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  String _apiErrorMessage(http.Response response) {
    if (response.statusCode == 401) {
      return 'Clé API OpenAI invalide ou expirée.';
    }
    if (response.statusCode == 429) {
      return 'Quota OpenAI dépassé. Réessaie plus tard.';
    }
    return 'OpenAI a répondu HTTP ${response.statusCode}.';
  }

  Future<String> _streamedErrorMessage(http.StreamedResponse response) async {
    if (response.statusCode == 401) return 'Clé API OpenAI invalide ou expirée.';
    if (response.statusCode == 429) return 'Quota OpenAI dépassé. Réessaie plus tard.';
    final body = await response.stream.bytesToString();
    return 'OpenAI a répondu HTTP ${response.statusCode}'
        '${body.trim().isEmpty ? '.' : ' : ${body.trim()}'}';
  }
}
