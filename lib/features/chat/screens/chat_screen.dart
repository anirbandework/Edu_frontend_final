// lib/features/chat/screens/chat_screen.dart
//
// Conversation list for teacher OR student (1:1 chat). Tapping a conversation
// opens the thread; "New chat" opens a contact picker. Content-only (wrapped by
// MainLayout). AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/chat_service.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('Messages', style: AppTheme.headingMedium)),
          ElevatedButton.icon(
            onPressed: _compose,
            icon: const Icon(Icons.edit, size: AppTheme.iconSmall),
            label: const Text('New chat'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            color: AppTheme.greenPrimary,
            tooltip: 'Refresh',
          ),
        ]),
        const SizedBox(height: 16),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 40, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error!,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
              label: const Text('Retry')),
        ]),
      );
    }
    if (_chats.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.forum_outlined, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No conversations yet',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _compose,
              icon: const Icon(Icons.edit, size: AppTheme.iconSmall),
              label: const Text('Start a chat')),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _chats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _chatTile(_chats[i]),
      ),
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
    return InkWell(
      borderRadius: AppTheme.borderRadius12,
      onTap: roomId.isEmpty ? null : () => _openThread(chatRoomId: roomId, counterpart: cp),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassCardDecoration,
        child: Row(
          children: [
            Stack(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.green50,
                child: Text(initials,
                    style: AppTheme.labelLarge.copyWith(color: AppTheme.greenPrimary)),
              ),
              if (online)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
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
                      style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(preview,
                      style: AppTheme.bodySmall.copyWith(
                          color: unread > 0 ? AppTheme.neutral700 : AppTheme.neutral500,
                          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                    color: AppTheme.greenPrimary, shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(12))),
                child: Text('$unread',
                    style: AppTheme.bodyMicro.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
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
                decoration: BoxDecoration(
                    color: AppTheme.neutral300, borderRadius: AppTheme.borderRadius8),
              ),
              const SizedBox(height: 12),
              Text(_isTeacher ? 'Message a student' : 'Message a teacher',
                  style: AppTheme.headingSmall),
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(_contacts.isEmpty ? 'No contacts available' : 'No matches',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
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
            child: Text(initials, style: AppTheme.labelMedium.copyWith(color: AppTheme.greenPrimary)),
          ),
          title: Text(name, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          subtitle: sub.isEmpty ? null : Text(sub, style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
          onTap: () => Navigator.pop(context, c),
        );
      },
    );
  }
}
