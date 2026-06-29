// lib/features/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/auth/auth_session.dart';
import '../../shared/widgets/login_card.dart';
import '../super_admin/widgets/sa_widgets.dart';

/// Standalone login page (super-admin / direct). Reuses the shared LoginCard so
/// it looks identical to the in-place picker dialog. Wrapped in a green branded
/// full-screen layout (EduAssist design system).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  String? _roleLabel(String? role) {
    switch (role) {
      case 'school_authority':
        return 'School Authority';
      case 'staff':
        return 'Staff';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = GoRouterState.of(context).uri.queryParameters;
    final school = q['school'];
    final hasSchool = school != null && school.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Stack(
        children: [
          // Green branded hero backdrop (the only gradient — AppTheme.primaryGradient).
          Container(
            height: MediaQuery.of(context).size.height * 0.42,
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button (white on the green hero) — keeps home navigation.
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Back',
                      onPressed: () => context.go(AppConstants.homeRoute),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        Sa.pagePad, Sa.gapXs, Sa.pagePad, Sa.gapLg * 2),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _brand(hasSchool ? school : null),
                            const SizedBox(height: Sa.gapLg * 1.5),
                            // White SaCard frame around the shared login form.
                            // LoginCard owns ALL phone+password fields,
                            // validation, auth and success navigation.
                            SaCard(
                              padding: const EdgeInsets.all(Sa.gapXs),
                              child: LoginCard(
                                schoolName: school,
                                roleLabel: _roleLabel(q['role']),
                                tenantId: q['tenantId'],
                                onSuccess: () => context
                                    .go(AuthSession.instance.landingRoute()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// White-on-green branding block shown above the form on the hero backdrop.
  Widget _brand(String? school) {
    final hasSchool = school != null && school.isNotEmpty;
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(Sa.radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.school, size: 30, color: Colors.white),
        ),
        const SizedBox(height: Sa.gap),
        Text(
          hasSchool ? school : 'EduAssist',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Sa.headerTitle.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 2),
        const Text(
          'Welcome back — sign in to continue',
          textAlign: TextAlign.center,
          style: Sa.headerSubtitle,
        ),
      ],
    );
  }
}
