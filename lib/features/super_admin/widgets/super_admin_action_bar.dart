// lib/features/super_admin/widgets/super_admin_action_bar.dart
//
// In-page action controls for the super-admin screens. The gradient header is a
// clean banner with NO buttons; every page action (Create, Refresh, …) lives
// here, inside the page body. The bar is a right-aligned Wrap so the buttons
// reflow onto new lines on narrow screens instead of overflowing — that is what
// makes the screens responsive on phones and split windows. AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';

/// A responsive, (by default) right-aligned row of page actions that sits in the
/// BODY of a super-admin screen. Wraps to new lines on narrow widths.
class SuperAdminActionBar extends StatelessWidget {
  final List<Widget> actions;
  final WrapAlignment alignment;
  const SuperAdminActionBar({
    super.key,
    required this.actions,
    this.alignment = WrapAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: alignment,
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      ),
    );
  }
}

/// Standard in-page action button used across the super-admin screens. Set
/// [primary] for the filled green call-to-action; otherwise it renders as a
/// green outlined button (used for Refresh and other secondary actions). When
/// [busy] is true the icon is replaced by a spinner and the button disables.
class SaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;
  const SaActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget leading = busy
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? Colors.white : AppTheme.greenPrimary,
            ),
          )
        : Icon(icon, size: AppTheme.iconSmall);

    if (primary) {
      return ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: leading,
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.greenPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius12),
          elevation: 0,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: leading,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.greenPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius12),
        side: const BorderSide(color: AppTheme.greenPrimary, width: 1.5),
      ),
    );
  }
}
