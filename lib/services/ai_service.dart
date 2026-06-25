// lib/services/ai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // SECURITY: never embed a provider API key in the client. LLM calls must be
  // proxied through the backend, which holds the key server-side and applies
  // per-user auth + rate limits. Until that proxy endpoint is wired, this
  // assistant uses safe local canned responses (no external key, no key leak).
  // TODO: POST {message} to a backend /api/ai/chat proxy with the bearer token.

  static const String _systemPrompt = '''
You are EduAssist AI, a helpful assistant for the EduAssist school management platform. 

EduAssist is a comprehensive school management platform with the following features:
- Multi-role access for Students, Teachers, and School Authorities
- Assignment and Grade Management
- Real-time Notifications and Communication
- Attendance tracking
- Timetable management
- Analytics and Reports
- Secure, scalable architecture
- Modern UI with responsive design

You should help users understand:
- How to use different features
- Platform capabilities
- Navigation and functionality
- Benefits for education management
- Technical questions about the system

Keep responses helpful, concise, and focused on EduAssist. Be friendly and professional.
''';

  static Future<String> getChatResponse(String userMessage) async {
    // No external provider key in the client. Use safe local responses for now;
    // route through a backend proxy (with the bearer token) when available.
    // _systemPrompt is retained for that future server-side proxy call.
    return _getDefaultResponse(userMessage);
  }

  static String _getDefaultResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.contains('feature') || lowerMessage.contains('what can')) {
      return '''EduAssist offers comprehensive school management features:

📚 **For Students**: Access assignments, grades, attendance records, and timetables
👨‍🏫 **For Teachers**: Manage classes, create assignments, track student progress, and send notifications  
🏫 **For Administrators**: Oversee entire school operations, analytics, and system management

Key capabilities include real-time notifications, grade management, attendance tracking, and detailed reporting. How can I help you with a specific feature?''';
    }
    
    if (lowerMessage.contains('how to') || lowerMessage.contains('help')) {
      return '''I'm here to help you navigate EduAssist! I can assist with:

• Understanding platform features
• Navigation guidance  
• Role-specific functionality
• Technical questions
• Best practices for school management

What specific area would you like help with?''';
    }
    
    return '''Thanks for your question about EduAssist! While I'm having trouble connecting to my full knowledge base right now, I can tell you that EduAssist is designed to streamline school management with features for students, teachers, and administrators.

Feel free to explore the platform or ask me about specific features like assignments, grades, notifications, or reports!''';
  }
}
