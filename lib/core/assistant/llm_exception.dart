/// Interface commune aux erreurs remontées par les clients de modèle
/// (`OllamaClient`, `OpenAiClient`, `AnthropicClient`, `GoogleAiClient`) —
/// chacun garde sa propre classe d'exception (pour rester testable/lisible
/// indépendamment), mais `implements LlmException` permet à
/// `AssistantChatController` et `assistant_screen.dart` d'attraper une
/// seule fois (`on LlmException`) plutôt que de dupliquer la gestion
/// d'erreur par fournisseur.
abstract interface class LlmException implements Exception {
  /// Message déjà prêt à afficher à l'utilisateur, en français.
  String get message;
}
