// lib/features/admin/widgets/attendance_dialog/bulk_mark_dialog.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../services/attendance_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkMarkDialog extends StatefulWidget {
  final AttendanceService service;
  final String tenantId;
  const BulkMarkDialog({super.key, required this.service, required this.tenantId});

  @override
  State<BulkMarkDialog> createState() => _BulkMarkDialogState();
}

class _BulkMarkDialogState extends State<BulkMarkDialog> {
  final _json = TextEditingController(text: '''
[
  {
    "user_id": "uuid-1",
    "user_type": "student",
    "class_id": "class-uuid",
    "attendance_date": "${DateTime.now().toIso8601String().split('T').first}",
    "attendance_type": "daily",
    "status": "present"
  }
]
''');

  bool _loading = false;

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 520.0);

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Green gradient header.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                    child: const Icon(Icons.upload_file_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: Sa.gap),
                  const Expanded(
                    child: Text(
                      'Bulk Mark Attendance',
                      style: Sa.headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Body.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste a JSON array of attendance records to mark them in '
                      'one request.',
                      style: Sa.body,
                    ),
                    const SizedBox(height: Sa.gap),
                    TextFormField(
                      controller: _json,
                      minLines: 10,
                      maxLines: 18,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppTheme.neutral800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Paste JSON array of attendance_records',
                        hintStyle: Sa.label,
                        filled: true,
                        fillColor: AppTheme.neutral50,
                        contentPadding: const EdgeInsets.all(12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppTheme.borderRadius12,
                          borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: AppTheme.borderRadius12,
                          borderSide: BorderSide(
                              color: AppTheme.greenPrimary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: 'Upload',
                    icon: Icons.cloud_upload_outlined,
                    busy: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final decoded = jsonDecode(_json.text);
      final list = List<Map<String, dynamic>>.from(decoded);

      final res = await widget.service.bulkMark(tenantId: widget.tenantId, records: list);
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
