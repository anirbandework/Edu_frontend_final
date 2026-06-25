// lib/features/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/auth/auth_session.dart';
import '../../shared/widgets/login_card.dart';

/// Standalone login page (super-admin / direct). Reuses the shared LoginCard so
/// it looks identical to the in-place picker dialog.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  String? _roleLabel(String? role) {
    switch (role) {
      case 'school_authority':
        return 'School Authority';
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = GoRouterState.of(context).uri.queryParameters;
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.greenPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.homeRoute),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LoginCard(
            schoolName: q['school'],
            roleLabel: _roleLabel(q['role']),
            tenantId: q['tenantId'],
            onForgot: () => context.go(AppConstants.forgotPasswordRoute),
            onSuccess: () => context.go(AuthSession.instance.landingRoute()),
          ),
        ),
      ),
    );
  }
}
