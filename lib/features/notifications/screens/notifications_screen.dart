// lib/features/notifications/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/notification.dart';
import '../../../services/notification_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;
  final String userType;
  final String tenantId;

  const NotificationsScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.tenantId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppNotification> _allNotifications = [];
  List<AppNotification> _unreadNotifications = [];
  List<AppNotification> _archivedNotifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
    _loadArchived();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (widget.userId.isEmpty || widget.tenantId.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [allNotifications, unreadNotifications] = await Future.wait([
        NotificationService.getNotificationsForUser(
          userId: widget.userId,
          userType: widget.userType,
          tenantId: widget.tenantId,
          unreadOnly: false,
        ),
        NotificationService.getNotificationsForUser(
          userId: widget.userId,
          userType: widget.userType,
          tenantId: widget.tenantId,
          unreadOnly: true,
        ),
      ]);

      setState(() {
        _allNotifications = allNotifications;
        _unreadNotifications = unreadNotifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the MainLayout shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Notifications',
          subtitle: _unreadNotifications.isEmpty
              ? 'You\'re all caught up'
              : '${_unreadNotifications.length} unread',
          icon: Icons.notifications,
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const SaLoading(message: 'Loading notifications…');
    }
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _loadNotifications);
    }
    return Column(
      children: [
        const SizedBox(height: Sa.gap),
        _tabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsList(_allNotifications),
              _buildNotificationsList(_unreadNotifications),
              _buildNotificationsList(_archivedNotifications, archived: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.neutral100,
                borderRadius: BorderRadius.circular(Sa.radius),
                border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.neutral600,
                labelStyle: Sa.cardTitle.copyWith(fontSize: 13),
                unselectedLabelStyle: Sa.value.copyWith(fontSize: 13),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppTheme.greenPrimary,
                  borderRadius: BorderRadius.circular(Sa.radius),
                ),
                tabs: [
                  Tab(text: 'All (${_allNotifications.length})'),
                  Tab(text: 'Unread (${_unreadNotifications.length})'),
                  Tab(text: 'Archived (${_archivedNotifications.length})'),
                ],
              ),
            ),
          ),
          if (_unreadNotifications.isNotEmpty) ...[
            const SizedBox(width: Sa.gapXs),
            IconButton(
              onPressed: _markAllAsRead,
              tooltip: 'Mark all read',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.done_all, color: AppTheme.greenPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<AppNotification> notifications,
      {bool archived = false}) {
    if (notifications.isEmpty) {
      return const SaStateView(
        icon: Icons.notifications_none,
        title: 'No notifications',
        subtitle: 'You\'re all caught up!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: Sa.gap),
          child: Dismissible(
            key: ValueKey(notification.id),
            background: _swipeBg(
                archived ? Icons.unarchive : Icons.archive,
                archived ? 'Unarchive' : 'Archive',
                AppTheme.greenPrimary,
                Alignment.centerLeft),
            secondaryBackground: _swipeBg(
                Icons.delete, 'Delete', AppTheme.error, Alignment.centerRight),
            confirmDismiss: (dir) => _onSwipe(notification, dir, archived),
            child: _buildNotificationCard(notification),
          ),
        );
      },
    );
  }

  Widget _swipeBg(IconData icon, String label, Color color, Alignment align) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(Sa.radius)),
      alignment: align,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// Returns true to let the tile dismiss (after the server action succeeds).
  Future<bool> _onSwipe(
      AppNotification n, DismissDirection dir, bool archived) async {
    try {
      if (dir == DismissDirection.endToStart) {
        await NotificationService.deleteNotification(
            notificationId: n.id, userId: widget.userId);
        _toast('Notification deleted', AppTheme.greenPrimary);
      } else if (archived) {
        await NotificationService.unarchive(
            notificationId: n.id, userId: widget.userId);
        _toast('Moved back to inbox', AppTheme.greenPrimary);
      } else {
        await NotificationService.archive(
            notificationId: n.id, userId: widget.userId);
        _toast('Notification archived', AppTheme.greenPrimary);
      }
      // Refresh both inbox and archive so counts/lists stay correct.
      _loadNotifications();
      _loadArchived();
      return true;
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
      return false;
    }
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _loadArchived() async {
    if (widget.userId.isEmpty || widget.tenantId.isEmpty) return;
    try {
      final archived = await NotificationService.getArchived(
        userId: widget.userId,
        userType: widget.userType,
        tenantId: widget.tenantId,
      );
      if (mounted) setState(() => _archivedNotifications = archived);
    } catch (_) {
      // Non-fatal; leave archived list as-is.
    }
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return SaCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _handleNotificationTap(notification),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getTypeColor(notification.notificationType)
                      .withValues(alpha: 0.12),
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Icon(
                  _getTypeIcon(notification.notificationType),
                  color: _getTypeColor(notification.notificationType),
                  size: 20,
                ),
              ),
              const SizedBox(width: Sa.gap),

              // Title and Priority
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Sa.cardTitle.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (notification.priority != NotificationPriority.normal) ...[
                          const SizedBox(width: Sa.gapXs),
                          SaStatusPill(
                            text: notification.priority.value.toUpperCase(),
                            color: _getPriorityColor(notification.priority),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _formatDateTime(notification.createdAt),
                          style: Sa.label,
                        ),
                        if (notification.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppTheme.neutral100,
                              borderRadius: AppTheme.borderRadius8,
                            ),
                            child: Text(
                              notification.category!,
                              style: Sa.label.copyWith(color: AppTheme.neutral700),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Unread indicator
              if (!notification.isRead) ...[
                const SizedBox(width: Sa.gapXs),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppTheme.greenPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: Sa.gap),

          // Message
          Text(
            notification.message,
            style: Sa.body.copyWith(
              color: notification.isRead
                  ? AppTheme.neutral600
                  : AppTheme.neutral800,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // Tags
          if (notification.tags != null && notification.tags!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: notification.tags!.take(3).map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.greenPrimary.withValues(alpha: 0.10),
                    borderRadius: AppTheme.borderRadius8,
                  ),
                  child: Text(
                    '#$tag',
                    style: Sa.label.copyWith(color: AppTheme.greenPrimary),
                  ),
                );
              }).toList(),
            ),
          ],

          // Action Button
          if (notification.actionText != null &&
              notification.actionUrl != null) ...[
            const SizedBox(height: Sa.gap),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _handleActionTap(notification),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(notification.actionText!),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.greenPrimary,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Keep all your existing helper methods
  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.grade:
        return Icons.grade;
      case NotificationType.attendance:
        return Icons.how_to_reg;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.alert:
        return Icons.warning;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  // Green for positive/active types, neutral for muted, red only for alerts.
  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return AppTheme.greenPrimary;
      case NotificationType.assignment:
        return AppTheme.neutral600;
      case NotificationType.grade:
        return AppTheme.greenLight;
      case NotificationType.attendance:
        return AppTheme.greenPrimary;
      case NotificationType.event:
        return AppTheme.greenSecondary;
      case NotificationType.reminder:
        return AppTheme.neutral600;
      case NotificationType.alert:
        return AppTheme.error;
      case NotificationType.general:
        return AppTheme.neutral500;
    }
  }

  // Neutral for low/normal, green for high (positive emphasis), red for urgent.
  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return AppTheme.neutral500;
      case NotificationPriority.normal:
        return AppTheme.neutral600;
      case NotificationPriority.high:
        return AppTheme.greenPrimary;
      case NotificationPriority.urgent:
        return AppTheme.error;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      try {
        await NotificationService.markAsRead(
          notificationId: notification.id,
          userId: widget.userId,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Couldn't update read status"),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }

    if (!notification.isRead) {
      setState(() {
        final index = _allNotifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _allNotifications[index] = notification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }

        _unreadNotifications.removeWhere((n) => n.id == notification.id);
      });
    }

    // Navigate to notification details
    _showNotificationDetails(notification);
  }

  void _handleActionTap(AppNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.launch, color: AppTheme.greenPrimary),
            const SizedBox(width: 8),
            Expanded(child: Text(notification.actionText ?? 'Action')),
          ],
        ),
        content: const Text('Opens the related item.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(AppNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getTypeIcon(notification.notificationType),
              color: _getTypeColor(notification.notificationType),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notification.title,
                style: Sa.cardTitle.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Metadata
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sent: ${_formatDateTime(notification.createdAt)}',
                      style: Sa.label,
                    ),
                    if (notification.isRead && notification.readAt != null)
                      Text(
                        'Read: ${_formatDateTime(notification.readAt!)}',
                        style: Sa.label,
                      ),
                    Text(
                      'Priority: ${notification.priority.value.toUpperCase()}',
                      style: Sa.label.copyWith(
                        color: _getPriorityColor(notification.priority),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Sa.gapLg),

              // Message
              Text(
                notification.message,
                style: Sa.body,
              ),

              if (notification.category != null) ...[
                const SizedBox(height: Sa.gapLg),
                Text(
                  'Category: ${notification.category}',
                  style: Sa.label,
                ),
              ],

              if (notification.tags != null && notification.tags!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: notification.tags!.map((tag) {
                    return Chip(
                      label: Text('#$tag'),
                      backgroundColor: AppTheme.greenPrimary.withValues(alpha: 0.10),
                      labelStyle: Sa.label.copyWith(color: AppTheme.greenPrimary),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (notification.actionText != null && notification.actionUrl != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _handleActionTap(notification);
              },
              icon: const Icon(Icons.launch, size: 16),
              label: Text(notification.actionText!),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    if (_unreadNotifications.isEmpty) return;

    try {
      // Persist server-side first: mark each unread notification as read.
      final unreadIds =
          _allNotifications.where((n) => !n.isRead).map((n) => n.id).toList();
      await Future.wait(unreadIds.map((id) => NotificationService.markAsRead(
            notificationId: id,
            userId: widget.userId,
          )));

      setState(() {
        for (int i = 0; i < _allNotifications.length; i++) {
          if (!_allNotifications[i].isRead) {
            _allNotifications[i] = _allNotifications[i].copyWith(
              isRead: true,
              readAt: DateTime.now(),
            );
          }
        }
        _unreadNotifications.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: AppTheme.greenPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
