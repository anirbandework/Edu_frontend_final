// lib/features/chat/screens/chat_screen.dart
//
// Conversation list for teacher OR student (1:1 chat). Tapping a conversation
// opens the thread; "New chat" opens a contact picker. Content-only (wrapped by
// MainLayout). AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/chat_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';
import 'chat_thread_screen.dart';

class ChatScreen extends StatefulWidget {
  final String role; // 'teacher' | 'student'
  final String? userId;
  final String? tenantId;
  const ChatScreen({super.key, required this.role, this.userId, this.tenantId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _chats = [];

  String get _userId => (widget.userId?.isNotEmpty == true)
      ? widget.userId!
      : (AuthSession.instance.userId ?? '');
  bool get _isTeacher => widget.role == 'teacher';
  String get _counterpartKey => _isTeacher ? 'student' : 'teacher';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No session found. Please sign in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = _isTeacher
          ? await ChatService.getTeacherChats(teacherId: _userId)
          : await ChatService.getStudentChats(studentId: _userId);
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _openThread({
    required String chatRoomId,
    required Map<String, dynamic> counterpart,
  }) async {
    final cpId = counterpart['id']?.toString() ?? '';
    final teacherId = _isTeacher ? _userId : cpId;
    final studentId = _isTeacher ? cpId : _userId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          chatRoomId: chatRoomId,
          teacherId: teacherId,
          studentId: studentId,
          myRole: widget.role,
          counterpartName: (counterpart['name'] ?? '').toString(),
          counterpartOnline: counterpart['is_online'] == true,
        ),
      ),
    );
    _load(); // refresh unread counts after returning
  }

  Future<void> _compose() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactPicker(role: widget.role, userId: _userId),
    );
    if (picked == null) return;
    final cpId = picked['id']?.toString() ?? '';
    if (cpId.isEmpty) return;
    try {
      final teacherId = _isTeacher ? _userId : cpId;
      final studentId = _isTeacher ? cpId : _userId;
      final room = await ChatService.getOrCreateRoom(teacherId: teacherId, studentId: studentId);
      final roomId = (room['chat_room_id'] ?? room['id'] ?? '').toString();
      if (roomId.isEmpty) return;
      if (!mounted) return;
      await _openThread(chatRoomId: roomId, counterpart: picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Messages',
          subtitle: 'Your conversations',
          icon: Icons.forum_outlined,
          trailing: SaHeaderAction(
            icon: Icons.edit_outlined,
            tooltip: 'New chat',
            onPressed: _compose,
          ),
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const SaLoading(message: 'Loading conversations…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);
    if (_chats.isEmpty) {
      return SaStateView(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        subtitle: 'Start a chat to begin messaging.',
        action: SaPrimaryButton(
          label: 'Start a chat',
          icon: Icons.edit_outlined,
          onPressed: _compose,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      itemCount: _chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _chatTile(_chats[i]),
    );
  }

  Widget _chatTile(Map<String, dynamic> chat) {
    final cp = (chat[_counterpartKey] as Map?)?.cast<String, dynamic>() ?? {};
    final name = (cp['name'] ?? 'Conversation').toString();
    final online = cp['is_online'] == true;
    final roomId = (chat['chat_room_id'] ?? '').toString();
    final unread = (chat['unread_count'] is num) ? (chat['unread_count'] as num).toInt() : 0;
    final last = (chat['last_message'] as Map?)?.cast<String, dynamic>();
    final preview = last == null ? 'No messages yet' : (last['message'] ?? '').toString();
    final initials = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return SaCard(
      padding: const EdgeInsets.all(12),
      onTap: roomId.isEmpty ? null : () => _openThread(chatRoomId: roomId, counterpart: cp),
      child: Row(
        children: [
          Stack(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.green50,
              child: Text(initials,
                  style: Sa.cardTitle.copyWith(color: AppTheme.greenPrimary)),
            ),
            if (online)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 13, height: 13,
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
              children: [
                Text(name,
                    style: Sa.cardTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(preview,
                    style: Sa.body.copyWith(
                        color: unread > 0 ? AppTheme.neutral700 : AppTheme.neutral500,
                        fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                  color: AppTheme.greenPrimary,
                  borderRadius: BorderRadius.all(Radius.circular(12))),
              child: Text('$unread',
                  style: const TextStyle(
                      fontFamily: AppTheme.interFontFamily,
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactPicker extends StatefulWidget {
  final String role;
  final String userId;
  const _ContactPicker({required this.role, required this.userId});

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _contacts = [];
  String _query = '';

  bool get _isTeacher => widget.role == 'teacher';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = _isTeacher
          ? await ChatService.availableStudents(teacherId: widget.userId)
          : await ChatService.availableTeachers(studentId: widget.userId);
      if (!mounted) return;
      setState(() {
        _contacts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _contacts;
    final q = _query.toLowerCase();
    return _contacts
        .where((c) => (c['name'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                decoration: const BoxDecoration(
                    color: AppTheme.neutral300, borderRadius: AppTheme.borderRadius8),
              ),
              const SizedBox(height: 12),
              Text(_isTeacher ? 'Message a student' : 'Message a teacher',
                  style: Sa.cardTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                    hintText: 'Search', prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Expanded(child: _list(controller)),
            ],
          ),
        );
      },
    );
  }

  Widget _list(ScrollController controller) {
    if (_loading) {
      return const SaLoading(message: 'Loading contacts…');
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: Sa.body.copyWith(color: AppTheme.neutral600)),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(_contacts.isEmpty ? 'No contacts available' : 'No matches',
            style: Sa.body.copyWith(color: AppTheme.neutral500)),
      );
    }
    return ListView.builder(
      controller: controller,
      itemCount: list.length,
      itemBuilder: (context, i) {
        final c = list[i];
        final name = (c['name'] ?? 'Contact').toString();
        final sub = (c['subject'] ?? c['student_id'] ?? c['email'] ?? '').toString();
        final initials = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.green50,
            child: Text(initials, style: Sa.value.copyWith(color: AppTheme.greenPrimary)),
          ),
          title: Text(name,
              style: Sa.value,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: sub.isEmpty
              ? null
              : Text(sub,
                  style: Sa.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.pop(context, c),
        );
      },
    );
  }
}
