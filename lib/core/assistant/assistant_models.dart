/// Rôle d'un message dans la conversation envoyée au modèle Ollama.
enum AssistantRole { system, user, assistant }

/// Un message de conversation, tel qu'affiché à l'écran et transmis à
/// l'API `/api/chat` d'Ollama.
class AssistantMessage {
  final AssistantRole role;
  final String content;

  const AssistantMessage({required this.role, required this.content});

  Map<String, dynamic> toApiJson() => {'role': role.name, 'content': content};
}
