// lib/features/admin/widgets/attendance_dialog/bulk_status_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../services/attendance_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkStatusDialog extends StatefulWidget {
  final AttendanceService service;
  const BulkStatusDialog({super.key, required this.service});

  @override
  State<BulkStatusDialog> createState() => _BulkStatusDialogState();
}

class _BulkStatusDialogState extends State<BulkStatusDialog> {
  final _ids = TextEditingController();
  final _updatedBy = TextEditingController();
  final _newStatus = TextEditingController(text: 'absent');
  bool _loading = false;

  @override
  void dispose() {
    _ids.dispose();
    _updatedBy.dispose();
    _newStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = math.min(media.size.width - 24, 480.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: media.size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Sa.gapLg, Sa.gapLg, Sa.gapLg, Sa.gap),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(
                      controller: _ids,
                      label: 'Attendance IDs',
                      hint: 'Comma-separated IDs',
                      icon: Icons.tag_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: Sa.gap),
                    _field(
                      controller: _updatedBy,
                      label: 'Updated By (UUID)',
                      hint: 'User UUID',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: Sa.gap),
                    _field(
                      controller: _newStatus,
                      label: 'New status',
                      hint: 'present / absent / late / excused / sick',
                      icon: Icons.flag_outlined,
                    ),
                  ],
                ),
              ),
            ),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Sa.gapLg, Sa.gapLg, Sa.gapLg, Sa.gapLg),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: const Icon(Icons.edit_calendar_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: Sa.gap),
          const Expanded(
            child: Text(
              'Bulk Update Status',
              style: Sa.headerTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Sa.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: !_loading,
          maxLines: maxLines,
          style: Sa.value,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Sa.body.copyWith(color: AppTheme.neutral400),
            prefixIcon: Icon(icon, size: 20, color: AppTheme.neutral500),
            filled: true,
            fillColor: AppTheme.neutral50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: AppTheme.borderRadius12,
              borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppTheme.borderRadius12,
              borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppTheme.borderRadius12,
              borderSide: BorderSide(color: Sa.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sa.gapLg, 0, Sa.gapLg, Sa.gapLg),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.neutral600,
                minimumSize: const Size(0, 48),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadius12),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: SaPrimaryButton(
              label: _loading ? 'Applying…' : 'Apply',
              icon: Icons.check_rounded,
              busy: _loading,
              expand: true,
              onPressed: _loading ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final ids = _ids.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final res = await widget.service.bulkUpdateStatus(
        attendanceIds: ids,
        newStatus: _newStatus.text.trim(),
        updatedBy: _updatedBy.text.trim(),
      );
      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
