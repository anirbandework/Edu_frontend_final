import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/class_model.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class ClassDetailsDialog extends StatefulWidget {
  final ClassModel model;
  final Future<Map<String, dynamic>> Function() fetch;
  const ClassDetailsDialog({super.key, required this.model, required this.fetch});

  @override
  State<ClassDetailsDialog> createState() => _ClassDetailsDialogState();
}

class _ClassDetailsDialogState extends State<ClassDetailsDialog> {
  Map<String, dynamic>? details;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final d = await widget.fetch(); if (mounted) setState(() => details = d); }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 480.0);
    final isActive = m.isActive;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient hero header.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: AppTheme.borderRadius12,
                    ),
                    child: const Icon(Icons.class_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: Text(
                      m.className,
                      style: Sa.headerTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                    splashRadius: 22,
                  ),
                ],
              ),
            ),
            // Body.
            Flexible(
              child: details == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: SaLoading(message: 'Loading details…'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: SaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SaInfoRow(label: 'Grade', value: '${m.gradeLevel}-${m.section}'),
                            const Divider(height: 1, color: Sa.stroke),
                            SaInfoRow(label: 'Year', value: m.academicYear),
                            const Divider(height: 1, color: Sa.stroke),
                            SaInfoRow(label: 'Capacity', value: '${m.currentStudents}/${m.maximumStudents}'),
                            const Divider(height: 1, color: Sa.stroke),
                            SaInfoRow(label: 'Room', value: m.classroom ?? '-'),
                            const Divider(height: 1, color: Sa.stroke),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(width: 104, child: Text('Status', style: Sa.label)),
                                  const SizedBox(width: Sa.gap),
                                  SaStatusPill(
                                    text: isActive ? 'Active' : 'Inactive',
                                    color: isActive ? AppTheme.greenPrimary : AppTheme.neutral400,
                                    icon: isActive ? Icons.check_circle_outline : Icons.remove_circle_outline,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            // Action.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.neutral600,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
