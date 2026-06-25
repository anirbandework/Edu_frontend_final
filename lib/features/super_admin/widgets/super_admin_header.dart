// lib/features/super_admin/widgets/super_admin_header.dart
//
// The shared gradient page header used across every super-admin screen
// (Organisations, Admins, Module Access, Analytics, Feedback) so the section has
// one consistent look. Title + subtitle + icon ONLY — it never carries action
// buttons. Page actions live in the body via SuperAdminActionBar, which keeps
// the banner clean and lets the layout reflow on small screens. AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';

class SuperAdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const SuperAdminHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.dashboard_customize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 480;
      final pad = compact ? 14.0 : 16.0;
      final box = compact ? 38.0 : 44.0;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(pad),
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          boxShadow: [AppTheme.greenShadow],
        ),
        child: Row(
          children: [
            Container(
              width: box,
              height: box,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: AppTheme.borderRadius12,
              ),
              child: Icon(icon, color: Colors.white, size: AppTheme.iconMedium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: (compact ? AppTheme.labelLarge : AppTheme.headingSmall)
                          .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
