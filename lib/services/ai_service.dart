// lib/services/ai_service.dart
class AIService {
  // SECURITY: never embed a provider API key in the client. LLM calls must be
  // proxied through the backend, which holds the key server-side and applies
  // per-user auth + rate limits. Until that proxy endpoint is wired, the
  // assistant has no real AI source and must not fabricate answers.
  // TODO: POST {message} to a backend /api/ai/chat proxy with the bearer token.

  static Future<String> getChatResponse(String userMessage) async {
    // No backend AI proxy endpoint exists yet. Do NOT return fabricated answers.
    // Throw so the UI surfaces its 'trouble connecting' state. When the backend
    // /api/ai/chat proxy is available, POST {message} (and a system prompt) using
    // AuthSession.instance.headers() and return the parsed assistant reply.
    throw UnimplementedError('AI assistant backend proxy is not available.');
  }
}
