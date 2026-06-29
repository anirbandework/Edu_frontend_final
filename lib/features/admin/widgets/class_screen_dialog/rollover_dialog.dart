import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class RolloverDialog extends StatefulWidget {
  final List<String> selectedIds;
  const RolloverDialog({super.key, required this.selectedIds});

  @override
  State<RolloverDialog> createState() => _RolloverDialogState();
}

class _RolloverDialogState extends State<RolloverDialog> {
  final from = TextEditingController();
  final to = TextEditingController();

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: Sa.label,
      hintStyle: Sa.label.copyWith(color: AppTheme.neutral400),
      filled: true,
      fillColor: AppTheme.neutral50,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.accent, width: 1.5),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      style: Sa.value,
      decoration: _decoration(label, hint),
    );
  }

  void _run() {
    Navigator.pop<Map<String, dynamic>>(context, {
      'from': from.text.trim(),
      'to': to.text.trim(),
      'ids': widget.selectedIds.isEmpty ? null : widget.selectedIds,
    });
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient header.
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Sa.radius),
                ),
                boxShadow: [AppTheme.greenShadow],
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
                      Icons.autorenew_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  const Expanded(
                    child: Text(
                      'Academic Year Rollover',
                      style: Sa.headerTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Body.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final fromField = _field(
                          from,
                          'From',
                          'e.g., 2024-25',
                        );
                        final toField = _field(to, 'To', 'e.g., 2025-26');
                        if (c.maxWidth < 600) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              fromField,
                              const SizedBox(height: Sa.gap),
                              toField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: fromField),
                            const SizedBox(width: Sa.gap),
                            Expanded(child: toField),
                          ],
                        );
                      },
                    ),
                    if (widget.selectedIds.isNotEmpty) ...[
                      const SizedBox(height: Sa.gap),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Sa.accent.withValues(alpha: 0.08),
                          borderRadius: AppTheme.borderRadius12,
                          border: Border.all(
                            color: Sa.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Sa.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Applies to ${widget.selectedIds.length} selected classes (or all if none selected).',
                                style: Sa.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: 'Run',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _run,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
