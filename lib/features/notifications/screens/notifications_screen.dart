// lib/features/notifications/screens/notifications_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/notification.dart';
import '../../../services/notification_service.dart';

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
  bool _useMockData = false; // CHANGED: Default to false for real API

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
      if (_useMockData) {
        // Use mock data for demonstration
        await Future.delayed(const Duration(milliseconds: 800)); // Simulate network delay
        
        final mockAllNotifications = _generateMockNotifications();
        final mockUnreadNotifications = mockAllNotifications.where((n) => !n.isRead).toList();

        setState(() {
          _allNotifications = mockAllNotifications;
          _unreadNotifications = mockUnreadNotifications;
          _isLoading = false;
        });
      } else {
        // Real API calls with debug info
        print('DEBUG: Loading notifications...');
        print('DEBUG: UserId: ${widget.userId}');
        print('DEBUG: UserType: ${widget.userType}');
        print('DEBUG: TenantId: ${widget.tenantId}');
        
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

        print('DEBUG: Loaded ${allNotifications.length} total notifications');
        print('DEBUG: Loaded ${unreadNotifications.length} unread notifications');

        setState(() {
          _allNotifications = allNotifications;
          _unreadNotifications = unreadNotifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG: Error loading notifications: $e');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'All (${_allNotifications.length})',
            ),
            Tab(
              text: 'Unread (${_unreadNotifications.length})',
            ),
            Tab(
              text: 'Archived (${_archivedNotifications.length})',
            ),
          ],
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
        actions: [
          // Toggle between mock and real data (for development)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'toggle_data') {
                setState(() {
                  _useMockData = !_useMockData;
                });
                _loadNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_useMockData ? 'Using mock data' : 'Using real API'),
                    backgroundColor: AppTheme.info,
                  ),
                );
              } else if (value == 'refresh') {
                _loadNotifications();
              }
            },
            itemBuilder: (context) => [
              if (kDebugMode)
                PopupMenuItem(
                  value: 'toggle_data',
                  child: Row(
                    children: [
                      Icon(_useMockData ? Icons.api : Icons.dashboard),
                      const SizedBox(width: 8),
                      Text(_useMockData ? 'Use Real API' : 'Use Mock Data'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
            ],
          ),
          if (_unreadNotifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark All Read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading notifications...'),
                ],
              ),
            )
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationsList(_allNotifications),
                    _buildNotificationsList(_unreadNotifications),
                    _buildNotificationsList(_archivedNotifications, archived: true),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.error),
          const SizedBox(height: 16),
          Text(
            'Error loading notifications',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
            ),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (kDebugMode) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _useMockData = true;
                    });
                    _loadNotifications();
                  },
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Use Demo Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.info,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              ElevatedButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<AppNotification> notifications,
      {bool archived = false}) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: AppTheme.neutral400,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.neutral600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up! 🎉',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Dismissible(
            key: ValueKey(notification.id),
            background: _swipeBg(
                archived ? Icons.unarchive : Icons.archive,
                archived ? 'Unarchive' : 'Archive',
                AppTheme.info,
                Alignment.centerLeft),
            secondaryBackground:
                _swipeBg(Icons.delete, 'Delete', AppTheme.error, Alignment.centerRight),
            confirmDismiss: (dir) =>
                _onSwipe(notification, dir, archived),
            child: _buildNotificationCard(notification),
          );
        },
      ),
    );
  }

  Widget _swipeBg(IconData icon, String label, Color color, Alignment align) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(12)),
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
        _toast('Notification deleted', AppTheme.success);
      } else if (archived) {
        await NotificationService.unarchive(
            notificationId: n.id, userId: widget.userId);
        _toast('Moved back to inbox', AppTheme.success);
      } else {
        await NotificationService.archive(
            notificationId: n.id, userId: widget.userId);
        _toast('Notification archived', AppTheme.success);
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: notification.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: !notification.isRead
            ? BorderSide(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Type Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor(notification.notificationType).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(notification.notificationType),
                      color: _getTypeColor(notification.notificationType),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Title and Priority
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                            if (notification.priority != NotificationPriority.normal)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(notification.priority),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  notification.priority.value.toUpperCase(),
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _formatDateTime(notification.createdAt),
                              style: AppTheme.bodyMicro.copyWith(
                                color: AppTheme.neutral600,
                              ),
                            ),
                            if (notification.category != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.neutral200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  notification.category!,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.neutral700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Unread indicator
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                notification.message,
                style: AppTheme.bodySmall.copyWith(
                  color: notification.isRead ? AppTheme.neutral700 : AppTheme.neutral900,
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$tag',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.info,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              // Action Button
              if (notification.actionText != null && notification.actionUrl != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _handleActionTap(notification),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(notification.actionText!),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return AppTheme.info;
      case NotificationType.assignment:
        return AppTheme.warning;
      case NotificationType.grade:
        return AppTheme.greenLight;
      case NotificationType.attendance:
        return Colors.purple;
      case NotificationType.event:
        return Colors.teal;
      case NotificationType.reminder:
        return AppTheme.warning;
      case NotificationType.alert:
        return AppTheme.error;
      case NotificationType.general:
        return AppTheme.neutral500;
    }
  }

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return AppTheme.neutral500;
      case NotificationPriority.normal:
        return AppTheme.info;
      case NotificationPriority.high:
        return AppTheme.warning;
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
    if (!notification.isRead && !_useMockData) {
      try {
        await NotificationService.markAsRead(
          notificationId: notification.id,
          userId: widget.userId,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error marking notification as read: $e');
        }
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
            Icon(Icons.launch, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Text(notification.actionText ?? 'Action'),
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
                style: AppTheme.bodyLarge,
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
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sent: ${_formatDateTime(notification.createdAt)}',
                      style: AppTheme.bodyMicro.copyWith(
                        color: AppTheme.neutral600,
                      ),
                    ),
                    if (notification.isRead && notification.readAt != null)
                      Text(
                        'Read: ${_formatDateTime(notification.readAt!)}',
                        style: AppTheme.bodyMicro.copyWith(
                          color: AppTheme.neutral600,
                        ),
                      ),
                    Text(
                      'Priority: ${notification.priority.value.toUpperCase()}',
                      style: AppTheme.bodyMicro.copyWith(
                        color: _getPriorityColor(notification.priority),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Message
              Text(
                notification.message,
                style: AppTheme.bodySmall,
              ),

              if (notification.category != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Category: ${notification.category}',
                  style: AppTheme.bodyMicro.copyWith(
                    color: AppTheme.neutral600,
                  ),
                ),
              ],
              
              if (notification.tags != null && notification.tags!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: notification.tags!.map((tag) {
                    return Chip(
                      label: Text('#$tag'),
                      backgroundColor: AppTheme.info.withOpacity(0.15),
                      labelStyle: AppTheme.bodySmall,
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
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // Keep your existing mock data method unchanged
  List<AppNotification> _generateMockNotifications() {
    // ... your existing mock data method
    return []; // Add your existing mock data here
  }
}
