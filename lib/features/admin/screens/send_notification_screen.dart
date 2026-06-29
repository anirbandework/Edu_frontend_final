// lib/features/admin/screens/send_notification_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/notification.dart';
import '../../../services/notification_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class SendNotificationScreen extends StatefulWidget {
  final String senderId;
  final String senderType;
  final String tenantId;

  const SendNotificationScreen({
    super.key,
    required this.senderId,
    required this.senderType,
    required this.tenantId,
  });

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _shortMessageController = TextEditingController();
  final _actionUrlController = TextEditingController();
  final _actionTextController = TextEditingController();

  NotificationType _selectedType = NotificationType.announcement;
  NotificationPriority _selectedPriority = NotificationPriority.normal;
  RecipientType _selectedRecipientType = RecipientType.all_students;
  final List<DeliveryChannel> _selectedChannels = [DeliveryChannel.inApp];

  bool _isScheduled = false;
  DateTime? _scheduledDateTime;
  DateTime? _expiresDateTime;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    // Check if we have valid parameters
    if (widget.senderId.isEmpty || widget.tenantId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showParameterError();
      });
    }
  }

  void _showParameterError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Missing Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Required information is missing:'),
            const SizedBox(height: 8),
            if (widget.senderId.isEmpty)
              const Text('• User ID is required'),
            if (widget.tenantId.isEmpty)
              const Text('• Tenant ID is required'),
            const SizedBox(height: 16),
            const Text('This usually happens when accessing the page directly. Please log in again through the proper flow.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(AppConstants.homeRoute);
            },
            child: const Text('Go to Home'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(AppConstants.loginRoute);
            },
            child: const Text('Login Again'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _shortMessageController.dispose();
    _actionUrlController.dispose();
    _actionTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the MainLayout shell provides them.
    return SaScreen(
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Send Notification',
          subtitle: 'Compose and deliver to your audience',
          icon: Icons.campaign_outlined,
        ),
      ),
      child: widget.senderId.isEmpty || widget.tenantId.isEmpty
          ? _buildErrorState()
          : _buildForm(),
    );
  }

  Widget _buildErrorState() {
    return SaStateView(
      icon: Icons.error_outline_rounded,
      iconColor: AppTheme.error,
      title: 'Missing Required Information',
      subtitle:
          'User ID and Tenant ID are required to send notifications.',
      action: SaPrimaryButton(
        label: 'Go to Home',
        icon: Icons.home_outlined,
        onPressed: () => context.go(AppConstants.homeRoute),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: Sa.gap),
            _buildRecipientSection(),
            const SizedBox(height: Sa.gap),
            _buildSettingsSection(),
            const SizedBox(height: Sa.gap),
            _buildSchedulingSection(),
            const SizedBox(height: Sa.gap),
            _buildActionSection(),
            const SizedBox(height: Sa.gapLg),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.info_outline,
            title: 'Basic Information',
          ),
          const SizedBox(height: Sa.gapLg),

          // Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'Enter notification title',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Title is required';
              }
              return null;
            },
            maxLength: 100,
          ),
          const SizedBox(height: Sa.gap),

          // Message
          TextFormField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Message *',
              hintText: 'Enter detailed message',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Message is required';
              }
              return null;
            },
            maxLength: 500,
          ),
          const SizedBox(height: Sa.gap),

          // Short Message
          TextFormField(
            controller: _shortMessageController,
            decoration: const InputDecoration(
              labelText: 'Short Message',
              hintText: 'Brief summary for push notifications',
              border: OutlineInputBorder(),
            ),
            maxLength: 160,
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientSection() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.people_outline,
            title: 'Recipients',
          ),
          const SizedBox(height: Sa.gapLg),

          DropdownButtonFormField<RecipientType>(
            initialValue: _selectedRecipientType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Recipient Type',
              border: OutlineInputBorder(),
            ),
            items: _getRecipientTypeOptions(),
            onChanged: (value) {
              setState(() {
                _selectedRecipientType = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<RecipientType>> _getRecipientTypeOptions() {
    final availableTypes = <RecipientType>[];

    if (widget.senderType == 'school_authority') {
      availableTypes.addAll([
        RecipientType.all_students,
        RecipientType.all_teachers,
        RecipientType.grade,
        RecipientType.class_level,
        RecipientType.broadcast,
      ]);
    } else if (widget.senderType == 'teacher') {
      availableTypes.addAll([
        RecipientType.all_students,
        RecipientType.grade,
        RecipientType.class_level,
      ]);
    }

    return availableTypes.map((type) {
      return DropdownMenuItem(
        value: type,
        child: Text(_getRecipientTypeDisplayName(type)),
      );
    }).toList();
  }

  String _getRecipientTypeDisplayName(RecipientType type) {
    switch (type) {
      case RecipientType.all_students:
        return 'All Students';
      case RecipientType.all_teachers:
        return 'All Teachers';
      case RecipientType.grade:
        return 'Specific Grade';
      case RecipientType.class_level:
        return 'Specific Class';
      case RecipientType.broadcast:
        return 'Everyone';
      case RecipientType.individual:
        return 'Individual';
      case RecipientType.group:
        return 'Group';
    }
  }

  Widget _buildSettingsSection() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.settings_outlined,
            title: 'Settings',
          ),
          const SizedBox(height: Sa.gapLg),

          // Notification Type
          DropdownButtonFormField<NotificationType>(
            initialValue: _selectedType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Notification Type',
              border: OutlineInputBorder(),
            ),
            items: NotificationType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getTypeDisplayName(type)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
          const SizedBox(height: Sa.gap),

          // Priority
          DropdownButtonFormField<NotificationPriority>(
            initialValue: _selectedPriority,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Priority',
              border: OutlineInputBorder(),
            ),
            items: NotificationPriority.values.map((priority) {
              return DropdownMenuItem(
                value: priority,
                child: Row(
                  children: [
                    Icon(
                      _getPriorityIcon(priority),
                      color: _getPriorityColor(priority),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_getPriorityDisplayName(priority)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPriority = value!;
              });
            },
          ),
          const SizedBox(height: Sa.gapLg),

          // Delivery Channels
          const Text('Delivery Channels', style: Sa.value),
          const SizedBox(height: Sa.gapXs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DeliveryChannel.values.map((channel) {
              final selected = _selectedChannels.contains(channel);
              return FilterChip(
                label: Text(_getChannelDisplayName(channel)),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedChannels.add(channel);
                    } else {
                      _selectedChannels.remove(channel);
                    }
                  });
                },
                selectedColor: AppTheme.greenPrimary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.neutral700,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulingSection() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.schedule_outlined,
            title: 'Scheduling',
          ),
          const SizedBox(height: Sa.gapXs),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Schedule for later', style: Sa.value),
            subtitle: const Text(
              'Send notification at a specific time',
              style: Sa.label,
            ),
            value: _isScheduled,
            onChanged: (value) {
              setState(() {
                _isScheduled = value;
                if (!value) {
                  _scheduledDateTime = null;
                }
              });
            },
            activeThumbColor: AppTheme.greenPrimary,
          ),

          if (_isScheduled) ...[
            const SizedBox(height: Sa.gapXs),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Schedule Date & Time', style: Sa.value),
              subtitle: Text(
                _scheduledDateTime != null
                    ? _scheduledDateTime!.toString()
                    : 'Tap to select',
                style: Sa.label,
              ),
              trailing: const Icon(
                Icons.calendar_today,
                color: AppTheme.neutral600,
              ),
              onTap: _selectScheduledDateTime,
            ),
          ],

          const SizedBox(height: Sa.gapXs),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expiration Date (Optional)', style: Sa.value),
            subtitle: Text(
              _expiresDateTime != null
                  ? _expiresDateTime!.toString()
                  : 'Notification will never expire',
              style: Sa.label,
            ),
            trailing: const Icon(
              Icons.event_busy,
              color: AppTheme.neutral600,
            ),
            onTap: _selectExpirationDateTime,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.touch_app_outlined,
            title: 'Action Button (Optional)',
          ),
          const SizedBox(height: Sa.gapLg),

          TextFormField(
            controller: _actionTextController,
            decoration: const InputDecoration(
              labelText: 'Button Text',
              hintText: 'e.g., View Assignment',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: Sa.gap),

          TextFormField(
            controller: _actionUrlController,
            decoration: const InputDecoration(
              labelText: 'Action URL',
              hintText: 'URL to navigate when button is tapped',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SaPrimaryButton(
      label: _isScheduled ? 'Schedule Notification' : 'Send Now',
      icon: _isScheduled ? Icons.schedule_send : Icons.send,
      busy: _isSending,
      expand: true,
      onPressed: _canSend() ? _sendNotification : null,
    );
  }

  bool _canSend() {
    return widget.senderId.isNotEmpty &&
           widget.tenantId.isNotEmpty &&
           _titleController.text.trim().isNotEmpty &&
           _messageController.text.trim().isNotEmpty;
  }

  Future<void> _selectScheduledDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectExpirationDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 23, minute: 59),
      );

      if (time != null) {
        setState(() {
          _expiresDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate() || !_canSend()) {
      return;
    }

    if (_selectedChannels.isEmpty) {
      _showErrorSnackBar('Please select at least one delivery channel');
      return;
    }

    if (_isScheduled && _scheduledDateTime == null) {
      _showErrorSnackBar('Please select a scheduled date and time');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final res = await NotificationService.sendNotification(
        senderId: widget.senderId,
        senderType: widget.senderType,
        tenantId: widget.tenantId,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        notificationType: _selectedType.value,
        recipientType: _selectedRecipientType.value,
        recipientConfig: _buildRecipientConfig(),
        priority: _selectedPriority.value,
        deliveryChannels: _selectedChannels.map((e) => e.value).toList(),
      );

      final delivered = res['total_recipients'] ?? res['delivered_count'];
      _showSuccessSnackBar(delivered != null
          ? 'Notification sent to $delivered recipients'
          : 'Notification sent successfully!');

      if (mounted) context.pop();
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  /// Recipient targeting config. all_students/all_teachers/broadcast need no
  /// config (server resolves the whole audience). grade/class_level/individual
  /// would need a picker (grade number / class_id / user_ids) — not yet in the
  /// UI, so those resolve to the broad audience for now.
  Map<String, dynamic> _buildRecipientConfig() {
    return {};
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.greenPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getTypeDisplayName(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.assignment:
        return 'Assignment';
      case NotificationType.grade:
        return 'Grade';
      case NotificationType.attendance:
        return 'Attendance';
      case NotificationType.event:
        return 'Event';
      case NotificationType.reminder:
        return 'Reminder';
      case NotificationType.alert:
        return 'Alert';
      case NotificationType.general:
        return 'General';
    }
  }

  String _getPriorityDisplayName(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.normal:
        return 'Normal';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.urgent:
        return 'Urgent';
    }
  }

  IconData _getPriorityIcon(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Icons.keyboard_arrow_down;
      case NotificationPriority.normal:
        return Icons.remove;
      case NotificationPriority.high:
        return Icons.keyboard_arrow_up;
      case NotificationPriority.urgent:
        return Icons.priority_high;
    }
  }

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

  String _getChannelDisplayName(DeliveryChannel channel) {
    switch (channel) {
      case DeliveryChannel.inApp:
        return 'In-App';
      case DeliveryChannel.email:
        return 'Email';
      case DeliveryChannel.sms:
        return 'SMS';
      case DeliveryChannel.push:
        return 'Push';
    }
  }
}
