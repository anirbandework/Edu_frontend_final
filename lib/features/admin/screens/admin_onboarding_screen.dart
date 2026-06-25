// lib/features/admin/screens/admin_onboarding_screen.dart
//
// Where a freshly-created admin lands the first time they sign in (no school
// yet). They create their first school here; on success the session is scoped
// to it and they enter their dashboard. If they already own schools, they can
// pick one to enter. Standalone full-screen (no shell). AppTheme only.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../../tenant_management/widgets/tenant_create_dialog.dart';

class AdminOnboardingScreen extends StatefulWidget {
  const AdminOnboardingScreen({super.key});

  @override
  State<AdminOnboardingScreen> createState() => _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState extends State<AdminOnboardingScreen> {
  bool _loading = true;
  bool _entering = false;
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final schools = await SuperAdminService.getMySchools();
      if (!mounted) return;
      setState(() {
        _schools = schools;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enter(String tenantId) async {
    if (_entering) return;
    setState(() => _entering = true);
    try {
      await SuperAdminService.switchSchool(tenantId: tenantId);
      if (!mounted) return;
      final uid = AuthSession.instance.userId ?? '';
      context.go('${AppConstants.adminDashboardRoute}?userId=$uid&tenantId=$tenantId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _entering = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _createSchool() {
    showDialog(
      context: context,
      builder: (_) => TenantCreateDialog(
        onTenantCreated: () async {
          // Adopt + enter the newly created school.
          final schools = await SuperAdminService.getMySchools();
          if (!mounted) return;
          setState(() => _schools = schools);
          if (schools.isNotEmpty) {
            await _enter(schools.first['id'].toString());
          }
        },
      ),
    );
  }

  void _logout() {
    AuthSession.instance.clear();
    context.go(AppConstants.homeRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: CircularProgressIndicator(color: AppTheme.greenPrimary)),
                    )
                  else if (_schools.isEmpty)
                    _createCard()
                  else
                    _schoolsCard(),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: AppTheme.iconSmall),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.borderRadius16,
        boxShadow: const [AppTheme.greenShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: AppTheme.borderRadius16),
            child: const Icon(Icons.add_business, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text('Welcome 👋',
              style: AppTheme.headingMedium.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            _schools.isEmpty
                ? "Let's set up your first school to get started. You can add more schools any time and switch between them."
                : 'Choose a school to manage, or create another.',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _createCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 48, color: AppTheme.greenPrimary),
          const SizedBox(height: 12),
          Text('Create your first school',
              style: AppTheme.headingSmall, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Add your school’s details — name, contact and capacity. You become its owner.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _entering ? null : _createSchool,
              icon: _entering
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add),
              label: Text(_entering ? 'Setting up…' : 'Create school'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _schoolsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your schools', style: AppTheme.labelLarge),
          const SizedBox(height: 8),
          ..._schools.map((s) {
            final id = s['id'].toString();
            final nm = (s['school_name'] ?? 'School').toString();
            final code = (s['school_code'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                borderRadius: AppTheme.borderRadius12,
                onTap: _entering ? null : () => _enter(id),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.neutral50, borderRadius: AppTheme.borderRadius12),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.green50,
                      child: Icon(Icons.business, color: AppTheme.greenPrimary, size: AppTheme.iconMedium),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nm,
                              style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (code.isNotEmpty)
                            Text(code,
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: AppTheme.greenPrimary, size: AppTheme.iconSmall),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _entering ? null : _createSchool,
            icon: const Icon(Icons.add, size: AppTheme.iconSmall),
            label: const Text('Create another school'),
          ),
        ],
      ),
    );
  }
}
