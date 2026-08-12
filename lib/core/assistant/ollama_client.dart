import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'assistant_models.dart';

/// Erreur remontée par l'API Ollama (instance injoignable, modèle absent,
/// réponse mal formée...) — avec un message déjà prêt à afficher à
/// l'utilisateur, en français.
class OllamaException implements Exception {
  final String message;
  const OllamaException(this.message);

  @override
  String toString() => message;
}

/// Client minimaliste de l'API locale Ollama.
///
/// Deux appels suffisent pour l'assistant :
/// - [listModels] (`GET /api/tags`) — liste les modèles disponibles sur
///   l'instance, pour laisser l'utilisateur choisir sans rien taper.
/// - [streamChat] (`POST /api/chat`, `stream: true`) — dialogue en streaming
///   : chaque morceau de texte généré est livré à [onToken] dès qu'il arrive,
///   pour un affichage "tape au fur et à mesure" dans le chat.
///
/// Aucune donnée ne quitte la machine (ou le réseau de l'utilisateur selon
/// l'adresse configurée) : tout passe par l'instance Ollama.
class OllamaClient {
  /// Message d'erreur remonté quand l'adresse configurée ne peut pas
  /// aboutir — avec la marche à suivre pour un Ollama local.
  static const invalidAddressMessage =
      'Adresse du serveur invalide. Pour ton Ollama local : '
      'http://localhost:11434 (lance « ollama serve »).';

  /// Normalise et valide la racine configurée pour pointer vers l'API
  /// native Ollama (`/api/...`) :
  /// - retire un éventuel `/v1` (format OpenAI) ou slash final ;
  /// - préfixe `http://` quand l'utilisateur n'a tapé que l'hôte (ex
  ///   `localhost:11434`).
  ///
  /// Lance [OllamaException] si l'adresse ne peut pas aboutir (schéma sans
  /// hôte, hôte vide...).
  static String normalizeBaseUrl(String baseUrl) {
    var url = baseUrl.trim();
    if (url.isEmpty) url = 'http://localhost:11434';
    // "http:", "https://", "http:///"... : un schéma sans hôte ne peut pas
    // aboutir — autant prévenir l'utilisateur que de lancer une résolution
    // DNS inutile.
    if (RegExp(r'^https?[:/]+$', caseSensitive: false).hasMatch(url)) {
      throw const OllamaException(invalidAddressMessage);
    }
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      url = 'http://$url';
    }
    url = url.replaceAll(RegExp(r'/+$'), '');
    if (url.endsWith('/v1')) url = url.substring(0, url.length - 3);
    return url;
  }

  /// `true` si [baseUrl] désigne une instance Ollama exploitable (schéma
  /// http(s) avec un hôte). Sert au chargement de la configuration à
  /// ramener une adresse corrompue vers la valeur par défaut.
  static bool isValidBaseUrl(String baseUrl) {
    try {
      final uri = Uri.parse('${normalizeBaseUrl(baseUrl)}/api/chat');
      final scheme = uri.scheme.toLowerCase();
      return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
    } on OllamaException {
      return false;
    }
  }

  Uri _api(String baseUrl, String path) {
    final uri = Uri.parse('${normalizeBaseUrl(baseUrl)}/api/$path');
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
      // Empêche `package:http` de lever son obscur ArgumentError (« No host
      // specified in URI ») : on remonte une erreur lisible à la place.
      throw const OllamaException(invalidAddressMessage);
    }
    return uri;
  }

  /// Liste les noms des modèles installés sur l'instance, triés par ordre
  /// alphabétique. Lance [OllamaException] si l'instance est injoignable ou
  /// renvoie une réponse inattendue.
  Future<List<String>> listModels(String baseUrl) async {
    final client = http.Client();
    try {
      final response = await client
          .get(_api(baseUrl, 'tags'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw OllamaException(
          'Ollama a répondu HTTP ${response.statusCode}. '
          'Vérifie que le serveur est bien lancé.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawModels = (decoded is Map<String, dynamic>)
          ? (decoded['models'] as List? ?? const [])
          : const [];
      final names = <String>[
        for (final m in rawModels)
          if (m is Map<String, dynamic> && (m['name'] is String))
            m['name'] as String,
      ]..sort();
      return names;
    } on SocketException {
      throw const OllamaException(
        'Impossible de joindre Ollama. Vérifie que le serveur est lancé '
        '(ollama serve), puis réessaie.',
      );
    } on FormatException {
      throw const OllamaException(
        'Réponse d\'Ollama illisible. Vérifie l\'adresse configurée.',
      );
    } finally {
      client.close();
    }
  }

  /// Dialogue en streaming avec le modèle [model].
  ///
  /// Chaque fragment de réponse généré est livré à [onToken] (accumulé dans
  /// le buffer retourné en fin d'appel). Si [isCancelled] retourne `true` en
  /// cours de route, le flux est interrompu proprement et la réponse partielle
  /// déjà accumulée est retournée.
  ///
  /// Lance [OllamaException] en cas d'erreur (instance injoignable, modèle
  /// inconnu...).
  Future<String> streamChat({
    required String baseUrl,
    required String model,
    required List<AssistantMessage> messages,
    void Function(String partial)? onToken,
    bool Function()? isCancelled,
  }) async {
    // Un premier appel peut renvoyer une réponse vide si Ollama recharge le
    // modèle (changement de contexte, relance du serveur) : on retente une
    // fois avant de remonter une erreur.
    var emptyResponses = 0;
    while (true) {
      final result = await _streamChatOnce(
        baseUrl: baseUrl,
        model: model,
        messages: messages,
        onToken: onToken,
        isCancelled: isCancelled,
      );
      if (result != null) return result;
      emptyResponses++;
      if (emptyResponses >= 2 || (isCancelled?.call() ?? false)) {
        throw const OllamaException(
          'Ollama n\'a rien renvoyé. Le modèle est peut-être en cours de '
          'chargement — réessaie dans un instant.',
        );
      }
    }
  }

  /// Une seule tentative de dialogue. Retourne `null` si le flux s'est
  /// terminé sans le moindre contenu (réponse vide d'Ollama).
  Future<String?> _streamChatOnce({
    required String baseUrl,
    required String model,
    required List<AssistantMessage> messages,
    void Function(String partial)? onToken,
    bool Function()? isCancelled,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', _api(baseUrl, 'chat'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': model,
        'messages': [for (final m in messages) m.toApiJson()],
        'stream': true,
        // gemma4 et les autres modèles « thinking » réfléchissent par défaut
        // : des minutes de tokens de raisonnement avant la moindre réponse.
        // On coupe ce mode pour un chat réactif.
        'think': false,
        'options': {
          // Le contexte par défaut d'Ollama (jusqu'à 262 144 tokens sur
          // gemma4) fait exploser le cache KV et la mémoire : la machine
          // swap et le modèle met des minutes à répondre. Borné à 8192,
          // un grand système + historique tient sans saturer la RAM.
          'num_ctx': 8192,
        },
      });

      final response = await client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw const OllamaException(
          'Le serveur Ollama ne répond plus. Réessaie dans un instant.',
        ),
      );
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw OllamaException(
          'Ollama a répondu HTTP ${response.statusCode}'
          '${body.trim().isEmpty ? '.' : ' : ${body.trim()}'}',
        );
      }

      final buffer = StringBuffer();
      await for (final line in utf8.decoder
          .bind(response.stream)
          .transform(const LineSplitter())) {
        if (isCancelled?.call() ?? false) break;
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is! Map<String, dynamic>) continue;
          final message = decoded['message'];
          if (message is Map<String, dynamic>) {
            final content = message['content'];
            if (content is String && content.isNotEmpty) {
              buffer.write(content);
              onToken?.call(content);
            }
          }
        } on FormatException {
          // Ligne JSON incomplète (fragment coupé par le réseau) : ignorée,
          // la suite du flux la complètera.
          continue;
        }
      }
      return buffer.isEmpty ? null : buffer.toString();
    } on SocketException {
      throw const OllamaException(
        'Impossible de joindre Ollama. Vérifie que le serveur est lancé '
        '(ollama serve), puis réessaie.',
      );
    } finally {
      client.close();
    }
  }
}
