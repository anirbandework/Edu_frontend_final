// lib/features/admin/screens/admin_onboarding_screen.dart
//
// Where a freshly-created admin lands the first time they sign in (no organisation
// yet). They create their first organisation here; on success the session is scoped
// to it and they enter their dashboard. If they already own organisations, they can
// pick one to enter. Standalone full-screen (no shell) — keeps its own Scaffold.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/super_admin_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';
import '../../organisation_management/widgets/organisation_create_dialog.dart';

class AdminOnboardingScreen extends StatefulWidget {
  const AdminOnboardingScreen({super.key});

  @override
  State<AdminOnboardingScreen> createState() => _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState extends State<AdminOnboardingScreen> {
  bool _loading = true;
  bool _entering = false;
  List<Map<String, dynamic>> _orgs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final organisations = await SuperAdminService.getMyOrganisations();
      if (!mounted) return;
      setState(() {
        _orgs = organisations;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enter(String organisationId) async {
    if (_entering) return;
    setState(() => _entering = true);
    try {
      await SuperAdminService.switchOrganisation(organisationId: organisationId);
      if (!mounted) return;
      final uid = AuthSession.instance.userId ?? '';
      context.go('${AppConstants.adminStaffRoute}?userId=$uid&organisationId=$organisationId');
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

  void _createOrg() {
    showDialog(
      context: context,
      builder: (_) => OrganisationCreateDialog(
        onOrganisationCreated: () async {
          // Adopt + enter the newly created organisation.
          final organisations = await SuperAdminService.getMyOrganisations();
          if (!mounted) return;
          setState(() => _orgs = organisations);
          if (organisations.isNotEmpty) {
            await _enter(organisations.first['id'].toString());
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
    // STANDALONE (pre-login, full-screen): keep our own Scaffold — NOT in the shell.
    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Sa.gapLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: Sa.gapLg),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: SaLoading(message: 'Loading your organisations…'),
                    )
                  else if (_orgs.isEmpty)
                    _createCard()
                  else
                    _orgsCard(),
                  const SizedBox(height: Sa.gap),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 44),
                    ),
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
    return SaGradientHeader(
      icon: Icons.add_business_outlined,
      title: _orgs.isEmpty ? 'Welcome' : 'Your organisations',
      subtitle: _orgs.isEmpty
          ? "Let's set up your first organisation to get started. You can add more and switch any time."
          : 'Choose a organisation to manage, or create another.',
    );
  }

  Widget _createCard() {
    return SaCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Sa.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.apartment_outlined,
                  size: 32, color: Sa.accent),
            ),
          ),
          const SizedBox(height: Sa.gap),
          Text('Create your first organisation',
              style: Sa.cardTitle.copyWith(fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: Sa.gapXs),
          const Text(
            'Add your organisation’s details — name, contact and capacity. You become its owner.',
            style: Sa.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Sa.gapLg),
          SaPrimaryButton(
            label: _entering ? 'Setting up…' : 'Create organisation',
            icon: Icons.add,
            busy: _entering,
            expand: true,
            onPressed: _entering ? null : _createOrg,
          ),
        ],
      ),
    );
  }

  Widget _orgsCard() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SaCardHeader(
            icon: Icons.apartment_outlined,
            title: 'Your organisations',
          ),
          const SizedBox(height: Sa.gap),
          ..._orgs.map((s) {
            final id = s['id'].toString();
            final nm = (s['name'] ?? 'Organisation').toString();
            final code = (s['code'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: AppTheme.neutral50,
                borderRadius: AppTheme.borderRadius12,
                child: InkWell(
                  borderRadius: AppTheme.borderRadius12,
                  onTap: _entering ? null : () => _enter(id),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Sa.accent.withValues(alpha: 0.12),
                          borderRadius: AppTheme.borderRadius12,
                        ),
                        child: const Icon(Icons.business,
                            color: Sa.accent, size: 20),
                      ),
                      const SizedBox(width: Sa.gap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(nm,
                                style: Sa.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (code.isNotEmpty)
                              Text(code,
                                  style: Sa.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: Sa.gapXs),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Sa.accent, size: 18),
                    ]),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: Sa.gap),
          OutlinedButton.icon(
            onPressed: _entering ? null : _createOrg,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create another organisation'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Sa.accent,
              minimumSize: const Size(0, 46),
              side: const BorderSide(color: Sa.accent, width: 1.5),
              shape: const RoundedRectangleBorder(
                  borderRadius: AppTheme.borderRadius12),
            ),
          ),
        ],
      ),
    );
  }
}
