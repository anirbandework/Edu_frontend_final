// lib/shared/widgets/ai_assistant_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../services/ai_service.dart';
import '../../core/services/ai_assistant_manager.dart';

class AIAssistantWidget extends ConsumerStatefulWidget {
  const AIAssistantWidget({super.key});

  @override
  ConsumerState<AIAssistantWidget> createState() => _AIAssistantWidgetState();
}

class _AIAssistantWidgetState extends ConsumerState<AIAssistantWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isChatOpen = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  // ✅ Enhanced keyboard handling
  double _keyboardHeight = 0;
  bool _isKeyboardVisible = false;
  final FocusNode _textFieldFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _addWelcomeMessage();
    WidgetsBinding.instance.addObserver(this);
    
    // ✅ Listen to focus changes to handle keyboard better
    _textFieldFocusNode.addListener(() {
      if (_textFieldFocusNode.hasFocus) {
        // Delay scroll to ensure keyboard is fully visible
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // ✅ Enhanced keyboard detection
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    setState(() {
      _keyboardHeight = bottomInset;
      _isKeyboardVisible = bottomInset > 0;
    });
    
    // ✅ Auto-scroll when keyboard appears/disappears
    if (_isChatOpen && _messages.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: "Hi! I'm EduAssist AI. I can help you understand our platform, features, and answer any questions about school management. How can I assist you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
    
    if (_isChatOpen) {
      _animationController.forward();
      // ✅ Focus and scroll after animation
      Future.delayed(const Duration(milliseconds: 350), () {
        _scrollToBottom();
      });
    } else {
      // ✅ Dismiss keyboard when closing chat
      _textFieldFocusNode.unfocus();
      _animationController.reverse();
    }
  }

  void _showHideOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.getGlassDecoration(
              borderRadius: AppTheme.borderRadius12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.borderRadius12,
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'AI Assistant Options',
                  style: AppTheme.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Would you like to hide the AI assistant? You can bring it back from the settings menu.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.neutral600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: AppTheme.textButtonStyle,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: AppTheme.borderRadius8,
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ref.read(aiAssistantProvider.notifier).hide();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Hide',
                            style: AppTheme.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await AIService.getChatResponse(message);
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I'm having trouble connecting right now. Please try again later.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ✅ Enhanced position calculations
  double get _bottomPosition {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_isKeyboardVisible && screenWidth < 600) {
      // Mobile with keyboard: Position above keyboard with safe margin
      return _keyboardHeight + 20;
    }
    return 20; // Default bottom position
  }

  double get _chatBottomPosition {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_isKeyboardVisible && screenWidth < 600) {
      // Chat window: Position above keyboard + floating button height + margin
      return _keyboardHeight + 80; // 56 (button) + 24 (margin)
    }
    return 80; // Default: above floating button
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ✅ Chat Window with enhanced positioning
        if (_isChatOpen)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            right: 20,
            bottom: _chatBottomPosition,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _buildChatWindow(context),
              ),
            ),
          ),
        
        // ✅ Floating Button with enhanced positioning
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          right: 20,
          bottom: _bottomPosition,
          child: _buildFloatingButton(),
        ),
      ],
    );
  }

  Widget _buildFloatingButton() {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onLongPress: () => _showHideOptions(context),
        child: InkWell(
          onTap: _toggleChat,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.greenPrimary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isChatOpen ? Icons.close : Icons.smart_toy,
                      key: ValueKey(_isChatOpen),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                if (!_isChatOpen)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatWindow(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // ✅ Enhanced height calculation for keyboard
    double chatHeight;
    if (_isKeyboardVisible && screenWidth < 600) {
      // Mobile with keyboard: Calculate available space
      final safeArea = MediaQuery.of(context).padding.top + MediaQuery.of(context).padding.bottom;
      final availableHeight = screenHeight - _keyboardHeight - safeArea - 160; // 160 = margins + button + status bar
      chatHeight = availableHeight.clamp(250.0, 400.0); // Reasonable bounds
    } else if (screenWidth < 600) {
      // Mobile without keyboard
      chatHeight = screenHeight * 0.6;
    } else {
      // Desktop/tablet
      chatHeight = 500;
    }

    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: AppTheme.borderRadius12,
      child: Container(
        width: screenWidth > 600 ? 380 : screenWidth * 0.85,
        height: chatHeight,
        decoration: AppTheme.getGlassDecoration(
          borderRadius: AppTheme.borderRadius12,
          border: Border.all(color: AppTheme.neutral200),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EduAssist AI',
                          style: AppTheme.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Online now',
                          style: AppTheme.bodyMicro.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            
            // ✅ Messages area with better spacing
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
              ),
            ),
            
            // ✅ Input area with better keyboard handling
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.neutral200)),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _textFieldFocusNode,
                        style: AppTheme.bodySmall,
                        decoration: InputDecoration(
                          hintText: 'Ask me anything about EduAssist...',
                          hintStyle: AppTheme.bodySmall.copyWith(
                            color: AppTheme.neutral400,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.neutral300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.greenPrimary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: _isLoading ? null : _sendMessage,
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? AppTheme.greenPrimary : AppTheme.neutral100,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Text(
                message.text,
                style: AppTheme.bodySmall.copyWith(
                  color: message.isUser ? Colors.white : AppTheme.neutral800,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.neutral300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person,
                color: AppTheme.neutral600,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        double opacity = (0.4 + (0.6 * (((_animationController.value * 3) - index) % 1.0))).clamp(0.4, 1.0);
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.neutral400.withOpacity(opacity),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
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
    required this.timestamp,
  });
}
