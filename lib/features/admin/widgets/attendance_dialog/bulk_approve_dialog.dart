// lib/features/admin/widgets/attendance_dialog/bulk_approve_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../services/attendance_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkApproveDialog extends StatefulWidget {
  final AttendanceService service;
  const BulkApproveDialog({super.key, required this.service});

  @override
  State<BulkApproveDialog> createState() => _BulkApproveDialogState();
}

class _BulkApproveDialogState extends State<BulkApproveDialog> {
  final _ids = TextEditingController();
  final _approvedBy = TextEditingController();
  final _remarks = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ids.dispose();
    _approvedBy.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 480.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient hero header.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Sa.gapLg),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Sa.radius),
                ),
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
                    child: const Icon(
                      Icons.done_all_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  const Expanded(
                    child: Text(
                      'Bulk Approve Absences',
                      style: Sa.headerTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable body.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Sa.gapLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(
                      controller: _ids,
                      label: 'Attendance IDs (comma-separated)',
                      icon: Icons.tag_rounded,
                    ),
                    const SizedBox(height: Sa.gap),
                    _field(
                      controller: _approvedBy,
                      label: 'Approved By (UUID)',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: Sa.gap),
                    _field(
                      controller: _remarks,
                      label: 'Approval Remarks (optional)',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            // Actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Sa.gapLg, 0, Sa.gapLg, Sa.gapLg),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _loading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.neutral600,
                        minimumSize: const Size(0, 48),
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.interFontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: SaPrimaryButton(
                      label: _loading ? 'Approving…' : 'Approve',
                      icon: Icons.check_rounded,
                      busy: _loading,
                      expand: true,
                      onPressed: _loading ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: Sa.value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Sa.label,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.neutral500),
        filled: true,
        fillColor: AppTheme.neutral50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Sa.accent, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final ids = _ids.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final res = await widget.service.bulkApproveAbsences(
        attendanceIds: ids,
        approvedBy: _approvedBy.text.trim(),
        approvalRemarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
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
