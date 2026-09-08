import 'dart:convert';

/// Message d'erreur commun aux clients cloud (`OpenAiClient`,
/// `AnthropicClient`, `GoogleAiClient`) pour une réponse HTTP non-200 :
/// remonte le message d'erreur réel renvoyé par le fournisseur
/// (`{"error": {"message": "..."}}`, présent chez les 3 API) plutôt qu'un
/// texte générique.
///
/// Un 429 recouvre des causes très différentes selon le fournisseur — chez
/// OpenAI par exemple, `insufficient_quota` (compte sans crédit/moyen de
/// paiement : se reproduit sur *chaque* appel tant que rien n'est ajouté sur
/// platform.openai.com, y compris le tout premier message d'une toute
/// nouvelle conversation) contre `rate_limit_exceeded` (vraiment
/// transitoire). Le texte précédent ("Quota dépassé. Réessaie plus tard.")
/// était trompeur dans le premier cas : le message du fournisseur explique
/// la vraie cause, on l'affiche donc directement quand il est disponible.
String llmApiErrorMessage({
  required String providerName,
  required int statusCode,
  required String body,
  // OpenAI/Anthropic utilisent 401 pour une clé invalide ; Google AI utilise
  // 400/403 selon le cas — personnalisable pour que le message générique de
  // repli (utilisé seulement si le corps ne contient pas déjà un message
  // exploitable) reste correct pour les 3 fournisseurs.
  Set<int> invalidKeyStatusCodes = const {401},
}) {
  final providerMessage = _extractErrorMessage(body);
  if (providerMessage != null && providerMessage.trim().isNotEmpty) {
    return '$providerName : ${providerMessage.trim()}';
  }
  if (invalidKeyStatusCodes.contains(statusCode)) {
    return 'Clé API $providerName invalide ou expirée.';
  }
  if (statusCode == 429) {
    return 'Quota $providerName dépassé. Si ça se reproduit dès le premier '
        'message plutôt qu\'après plusieurs, le compte n\'a probablement '
        'plus de crédit disponible — vérifie le solde/moyen de paiement '
        'chez $providerName plutôt que de réessayer plus tard.';
  }
  return '$providerName a répondu HTTP $statusCode.';
}

/// Cherche `error.message` dans le corps JSON de la réponse — forme
/// commune aux erreurs OpenAI/Anthropic/Google. `null` si le corps n'est
/// pas du JSON exploitable (page d'erreur HTML d'un proxy, corps vide...).
String? _extractErrorMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final error = decoded['error'];
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    return null;
  } on FormatException {
    return null;
  }
}
