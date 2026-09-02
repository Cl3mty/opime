/// Fournisseur de modèle utilisé par l'assistant IA.
///
/// [ollama] est le fournisseur local historique (aucune donnée ne quitte la
/// machine, voir `OllamaClient`). Les trois autres sont des fournisseurs
/// cloud, connectés via une clé API saisie par l'utilisateur dans les
/// Réglages (voir `AssistantConfigController.apiKeyFor`) — aucun de ces
/// fournisseurs n'expose de connexion "avec son compte" (OAuth) pour une
/// application tierce comme Opime, une clé API est le mécanisme standard.
enum LlmProvider {
  ollama('Ollama (local)'),
  openai('OpenAI'),
  anthropic('Anthropic (Claude)'),
  google('Google (Gemini)');

  final String label;

  const LlmProvider(this.label);

  /// Faux uniquement pour [ollama] : conditionne l'affichage du champ clé
  /// API et de l'avertissement de confidentialité dans les Réglages, ainsi
  /// que le choix du client HTTP dans `AssistantChatController`.
  bool get isCloud => this != LlmProvider.ollama;
}
