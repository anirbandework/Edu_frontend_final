import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkUpdateStatusDialog extends StatelessWidget {
  const BulkUpdateStatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    bool active = true;
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
        child: StatefulBuilder(
          builder: (_, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gradient header.
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(Sa.radius),
                    ),
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
                        child: const Icon(
                          Icons.sync_alt_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: Sa.gap),
                      const Expanded(
                        child: Text(
                          'Bulk Status',
                          style: Sa.headerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body.
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Sa.surface,
                        borderRadius: BorderRadius.circular(Sa.radius),
                        border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
                      ),
                      child: SwitchListTile(
                        value: active,
                        activeThumbColor: Sa.accent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Sa.radius),
                        ),
                        onChanged: (v) => setState(() => active = v),
                        title: Text(
                          active ? 'Set Active' : 'Set Inactive',
                          style: Sa.value,
                        ),
                        subtitle: Text(
                          active
                              ? 'Selected items will be marked active.'
                              : 'Selected items will be marked inactive.',
                          style: Sa.label,
                        ),
                      ),
                    ),
                  ),
                ),

                // Actions.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
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
                      const Spacer(),
                      SaPrimaryButton(
                        label: 'Apply',
                        icon: Icons.check_rounded,
                        onPressed: () => Navigator.pop<bool>(context, active),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
