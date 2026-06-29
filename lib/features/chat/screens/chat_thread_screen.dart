// lib/features/chat/screens/chat_thread_screen.dart
//
// A 1:1 conversation thread. Pushed as a full page (own Scaffold). Loads message
// history, polls every few seconds for new messages, marks incoming as read, and
// sends via REST. AppTheme only.
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/chat_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class ChatThreadScreen extends StatefulWidget {
  final String chatRoomId;
  final String teacherId;
  final String studentId;
  final String myRole; // 'teacher' | 'student'
  final String counterpartName;
  final bool counterpartOnline;

  const ChatThreadScreen({
    super.key,
    required this.chatRoomId,
    required this.teacherId,
    required this.studentId,
    required this.myRole,
    required this.counterpartName,
    this.counterpartOnline = false,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final msgs = await ChatService.getHistory(chatRoomId: widget.chatRoomId, limit: 100);
      // History may arrive newest-first or oldest-first; sort ascending by time.
      msgs.sort((a, b) => (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
      if (!mounted) return;
      final wasAtBottom = !_scroll.hasClients ||
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 80;
      final grew = msgs.length != _messages.length;
      setState(() {
        _messages = msgs;
        _loading = false;
        _error = null;
      });
      if (initial || (grew && wasAtBottom)) _jumpToBottom();
      // Clear unread for incoming messages.
      ChatService.markRead(chatRoomId: widget.chatRoomId).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_messages.isEmpty) _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService.sendMessage(
        teacherId: widget.teacherId,
        studentId: widget.studentId,
        message: text,
        senderType: widget.myRole,
      );
      _input.clear();
      if (!mounted) return;
      setState(() => _sending = false);
      await _load();
      _jumpToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.counterpartName.isNotEmpty
        ? widget.counterpartName.trim()[0].toUpperCase()
        : '?';
    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      appBar: AppBar(
        backgroundColor: AppTheme.greenPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(initials,
                  style: Sa.value.copyWith(color: Colors.white)),
            ),
            if (widget.counterpartOnline)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    color: AppTheme.greenPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.counterpartName.isEmpty ? 'Conversation' : widget.counterpartName,
                    style: Sa.headerTitle.copyWith(fontSize: 16),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(widget.counterpartOnline ? 'Online' : 'Offline',
                    style: Sa.headerSubtitle.copyWith(
                        color: widget.counterpartOnline ? Colors.white : Colors.white70)),
              ],
            ),
          ),
        ]),
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          _composer(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SaLoading(message: 'Loading…');
    }
    if (_error != null && _messages.isEmpty) {
      return SaStateView.error(message: _error!, onRetry: () => _load(initial: true));
    }
    if (_messages.isEmpty) {
      return const SaStateView(
        icon: Icons.chat_bubble_outline,
        title: 'No messages yet',
        subtitle: 'Say hello 👋',
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(_messages[i]),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final isMine = (m['sender_type'] ?? '').toString() == widget.myRole;
    final text = (m['message'] ?? '').toString();
    final time = _fmtTime((m['created_at'] ?? '').toString());
    final maxBubble = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxBubble),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.greenPrimary : AppTheme.neutral100,
          border: isMine ? null : Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
          boxShadow: isMine ? null : Sa.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                style: Sa.body.copyWith(
                    color: isMine ? Colors.white : AppTheme.neutral800)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(time,
                  style: Sa.label.copyWith(
                      fontSize: 11,
                      color: isMine ? Colors.white70 : AppTheme.neutral400)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final l = dt.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    final ap = l.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.neutral200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: AppTheme.neutral100,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppTheme.greenPrimary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
