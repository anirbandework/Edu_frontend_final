// lib/features/ai/services/ai_assistant_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider to manage AI assistant state
final aiAssistantProvider = StateNotifierProvider<AIAssistantNotifier, AIAssistantState>((ref) {
  return AIAssistantNotifier();
});

class AIAssistantState {
  final bool isVisible;
  final bool isExpanded;
  final List<ChatMessage> messages;
  
  const AIAssistantState({
    this.isVisible = true,
    this.isExpanded = false,
    this.messages = const [],
  });
  
  AIAssistantState copyWith({
    bool? isVisible,
    bool? isExpanded,
    List<ChatMessage>? messages,
  }) {
    return AIAssistantState(
      isVisible: isVisible ?? this.isVisible,
      isExpanded: isExpanded ?? this.isExpanded,
      messages: messages ?? this.messages,
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AIAssistantNotifier extends StateNotifier<AIAssistantState> {
  AIAssistantNotifier() : super(const AIAssistantState());
  
  void toggle() {
    state = state.copyWith(isVisible: !state.isVisible);
  }
  
  void show() {
    state = state.copyWith(isVisible: true);
  }
  
  void hide() {
    state = state.copyWith(isVisible: false, isExpanded: false);
  }
  
  void expand() {
    state = state.copyWith(isExpanded: true);
  }
  
  void collapse() {
    state = state.copyWith(isExpanded: false);
  }
  
  void addMessage(String text, bool isUser) {
    final newMessage = ChatMessage(text: text, isUser: isUser);
    final updatedMessages = [...state.messages, newMessage];
    state = state.copyWith(messages: updatedMessages);
  }
}

// Global context holder for managing AI assistant across the app
class AIAssistantManager {
  static WidgetRef? _ref;
  
  static void initialize(WidgetRef ref) {
    _ref = ref;
    debugPrint('AI Assistant initialized');
  }
  
  static void show() {
    _ref?.read(aiAssistantProvider.notifier).show();
  }
  
  static void hide() {
    _ref?.read(aiAssistantProvider.notifier).hide();
  }
  
  static void toggle() {
    _ref?.read(aiAssistantProvider.notifier).toggle();
  }
}
