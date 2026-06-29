import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class UpdateStudentCountDialog extends StatefulWidget {
  final int maxCount;
  final int current;
  const UpdateStudentCountDialog({super.key, required this.maxCount, required this.current});
  @override
  State<UpdateStudentCountDialog> createState() => _UpdateStudentCountDialogState();
}

class _UpdateStudentCountDialogState extends State<UpdateStudentCountDialog> {
  late TextEditingController ctrl;
  @override
  void initState() { super.initState(); ctrl = TextEditingController(text: widget.current.toString()); }

  @override
  void dispose() { ctrl.dispose(); super.dispose(); }

  void _apply() {
    final v = int.tryParse(ctrl.text) ?? widget.current;
    if (v <= widget.maxCount) {
      Navigator.pop<int>(context, v);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exceeds max capacity'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width - 24;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.min(maxW, 460)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Sa.accent.withValues(alpha: 0.10),
                      borderRadius: AppTheme.borderRadius8,
                    ),
                    child: const Icon(Icons.groups_outlined, size: 17, color: Sa.accent),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Update Student Count', style: Sa.cardTitle)),
                ],
              ),
              const SizedBox(height: Sa.gapLg),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                onSubmitted: (_) => _apply(),
                style: Sa.value,
                cursorColor: Sa.accent,
                decoration: InputDecoration(
                  labelText: 'New count (max ${widget.maxCount})',
                  labelStyle: Sa.label,
                  filled: true,
                  fillColor: AppTheme.neutral50,
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
              const SizedBox(height: Sa.gapLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: 'Apply',
                    icon: Icons.check_rounded,
                    onPressed: _apply,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
