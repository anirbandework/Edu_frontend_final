import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class ConfirmBulkDeleteDialog extends StatelessWidget {
  final int count;
  const ConfirmBulkDeleteDialog({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final maxW = math.min(MediaQuery.of(context).size.width - 24, 480.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: const EdgeInsets.all(Sa.gapLg),
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
                      color: AppTheme.error.withValues(alpha: 0.10),
                      borderRadius: AppTheme.borderRadius8,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: AppTheme.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Delete Classes', style: Sa.cardTitle),
                  ),
                ],
              ),
              const SizedBox(height: Sa.gap),
              Text(
                'Are you sure you want to delete $count '
                '${count == 1 ? 'class' : 'classes'}? This performs a soft delete.',
                style: Sa.body,
              ),
              const SizedBox(height: Sa.gapLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    color: AppTheme.error,
                    onPressed: () => Navigator.pop(context, true),
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
