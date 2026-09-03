import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'assistant_models.dart';
import 'llm_error_message.dart';
import 'llm_exception.dart';

/// Erreur remontée par l'API Google AI / Gemini (clé invalide, quota
/// dépassé, réponse mal formée...) — avec un message déjà prêt à afficher
/// à l'utilisateur, en français.
class GoogleAiException implements LlmException {
  @override
  final String message;
  const GoogleAiException(this.message);

  @override
  String toString() => message;
}

/// Client minimaliste de l'API Google AI (Gemini,
/// `https://generativelanguage.googleapis.com/v1beta`), authentifié par clé
/// API (voir `AssistantConfigController.apiKeyFor`) — contrairement à
/// [OllamaClient], les messages envoyés quittent la machine et sont traités
/// par les serveurs de Google.
///
/// Deux différences par rapport aux autres clients :
/// - le prompt système n'est pas un message de rôle `system` mais un champ
///   `systemInstruction` séparé, extrait par [streamChat] comme pour
///   [AnthropicClient] ;
/// - le rôle assistant se nomme `model`, pas `assistant`.
class GoogleAiClient {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Client HTTP injectable pour les tests (ex : `http.testing.MockClient`) —
  /// `null` en usage normal, où chaque appel crée puis referme son propre
  /// `http.Client()`, comme [OllamaClient].
  final http.Client? _injectedClient;

  GoogleAiClient({http.Client? httpClient}) : _injectedClient = httpClient;

  /// Liste les modèles supportant la génération de texte pour cette clé,
  /// triés par ordre alphabétique (préfixe `models/` retiré). Lance
  /// [GoogleAiException] si la clé est invalide ou l'API injoignable.
  Future<List<String>> listModels(String apiKey) async {
    final client = _injectedClient ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('$_baseUrl/models?key=$apiKey'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw GoogleAiException(
          llmApiErrorMessage(
            providerName: 'Google AI',
            statusCode: response.statusCode,
            body: response.body,
            invalidKeyStatusCodes: const {400, 403},
          ),
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawModels = (decoded is Map<String, dynamic>)
          ? (decoded['models'] as List? ?? const [])
          : const [];
      final names = <String>[
        for (final m in rawModels)
          if (m is Map<String, dynamic> &&
              (m['name'] is String) &&
              _supportsGenerateContent(m))
            (m['name'] as String).replaceFirst('models/', ''),
      ]..sort();
      return names;
    } on SocketException {
      throw const GoogleAiException(
        'Impossible de joindre l\'API Google AI. Vérifie ta connexion réseau.',
      );
    } on FormatException {
      throw const GoogleAiException('Réponse de Google AI illisible.');
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  bool _supportsGenerateContent(Map<String, dynamic> model) {
    final methods = model['supportedGenerationMethods'] as List?;
    return methods?.contains('generateContent') ?? false;
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

      final uri = Uri.parse(
        '$_baseUrl/models/$model:streamGenerateContent?alt=sse&key=$apiKey',
      );
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        if (systemPrompt.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
        'contents': [
          for (final m in conversation)
            {
              'role': m.role == AssistantRole.assistant ? 'model' : 'user',
              'parts': [
                {'text': m.content},
              ],
            },
        ],
      });

      final response = await client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw const GoogleAiException(
          'L\'API Google AI ne répond plus. Réessaie dans un instant.',
        ),
      );
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw GoogleAiException(
          llmApiErrorMessage(
            providerName: 'Google AI',
            statusCode: response.statusCode,
            body: body,
            invalidKeyStatusCodes: const {400, 403},
          ),
        );
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
          final candidates = decoded['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;
          final content = candidates.first['content'];
          final parts = content is Map<String, dynamic>
              ? content['parts'] as List?
              : null;
          if (parts == null) continue;
          for (final part in parts) {
            if (part is Map<String, dynamic> && part['text'] is String) {
              final text = part['text'] as String;
              if (text.isEmpty) continue;
              buffer.write(text);
              onToken?.call(text);
            }
          }
        } on FormatException {
          // Ligne JSON incomplète (fragment coupé par le réseau) : ignorée,
          // la suite du flux la complètera.
          continue;
        }
      }
      return buffer.toString();
    } on SocketException {
      throw const GoogleAiException(
        'Impossible de joindre l\'API Google AI. Vérifie ta connexion réseau.',
      );
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

}
