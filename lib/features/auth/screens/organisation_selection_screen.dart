// lib/features/auth/screens/organisation_selection_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/organisation.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/login_card.dart';
import '../../../core/auth/auth_session.dart';
import '../../organisation/services/organisation_management_service.dart';
import '../../../shared/widgets/sa_widgets.dart';

class OrganisationSelectionScreen extends StatefulWidget {
  const OrganisationSelectionScreen({super.key});

  @override
  State<OrganisationSelectionScreen> createState() => _OrganisationSelectionScreenState();
}

class _OrganisationSelectionScreenState extends State<OrganisationSelectionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController searchController = TextEditingController();
  List<Organisation> organisations = [];
  List<Organisation> filteredOrgs = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? error;
  int currentPage = 1;
  final int pageSize = 50;
  bool hasMoreData = true;
  bool includeInactive = false;
  Timer? _debounce; // debounces server-side search keystrokes

  AnimationController? animationController;
  Animation<double>? fadeAnimation;
  Animation<Offset>? slideAnimation;

  @override
  void initState() {
    super.initState();
    setupAnimations();
    searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => loadOrgs());
  }

  /// Debounced server-side search — refetch from the API ~350ms after typing stops
  /// (the picker no longer loads every org, so filtering must happen on the server).
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) loadOrgs(true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    animationController?.dispose();
    super.dispose();
  }

  void setupAnimations() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animationController!,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animationController!,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    animationController!.forward();
  }

  Future<void> loadOrgs([bool refresh = false]) async {
    if (!mounted) return;

    if (refresh) {
      currentPage = 1;
      hasMoreData = true;
      organisations.clear();
    }

    setState(() {
      if (refresh) {
        isLoading = true;
      } else {
        isLoadingMore = true;
      }
      error = null;
    });

    try {
      final newOrgs = await OrganisationService.getPublicOrganisations(
        query: searchController.text,
      );

      if (!mounted) return;

      organisations = newOrgs;
      hasMoreData = false; // server returns a capped, already-filtered page

      filteredOrgs = organisations;
    } catch (e) {
      if (!mounted) return;
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
      }
    }
  }

  void toggleIncludeInactive() {
    setState(() {
      includeInactive = !includeInactive;
    });
    loadOrgs(true);
  }

  @override
  Widget build(BuildContext context) {
    if (animationController == null || fadeAnimation == null || slideAnimation == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundPrimary,
        body: SaLoading(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: FadeTransition(
          opacity: fadeAnimation!,
          child: SlideTransition(
            position: slideAnimation!,
            child: Column(
              children: [
                buildHeader(),
                buildSearchSection(),
                if (includeInactive) buildInactiveInfo(),
                Expanded(
                  child: isLoading
                      ? const SaLoading(message: 'Loading organisations…')
                      : error != null
                          ? buildErrorState()
                          : filteredOrgs.isEmpty
                              ? buildEmptyState()
                              : buildOrgsList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: SaGradientHeader(
        title: 'Select Organisation',
        subtitle: 'Choose your organisation to continue',
        icon: Icons.apartment_outlined,
        leading: _headerButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onTap: () => context.go(AppConstants.homeRoute),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _headerButton(
              icon: includeInactive ? Icons.visibility : Icons.visibility_off,
              tooltip: includeInactive
                  ? 'Hide Inactive Organisations'
                  : 'Show Inactive Organisations',
              onTap: toggleIncludeInactive,
            ),
            const SizedBox(width: Sa.gapXs),
            _headerButton(
              icon: Icons.login_rounded,
              tooltip: 'Sign in',
              onTap: _openDirectLogin,
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: AppTheme.borderRadius12,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius12,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: SearchBarWidget(
        controller: searchController,
        hintText: 'Search by name, address, or head…',
      ),
    );
  }

  Widget buildInactiveInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(Sa.radius),
        border: Border.all(color: Sa.stroke),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            color: AppTheme.neutral600,
            size: 16,
          ),
          SizedBox(width: Sa.gapXs),
          Expanded(
            child: Text(
              'Showing active and inactive organisations',
              style: Sa.label,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorState() {
    return SaStateView.error(
      message: error ?? 'Unable to load organisations.',
      onRetry: () => loadOrgs(true),
    );
  }

  Widget buildEmptyState() {
    return SaStateView(
      icon: Icons.apartment_outlined,
      title: 'No organisations found',
      subtitle: searchController.text.isNotEmpty
          ? 'Try adjusting your search terms or clear the search to see all organisations.'
          : includeInactive
              ? 'No organisations are currently available.'
              : 'Try including inactive organisations to see more results.',
      action: searchController.text.isNotEmpty
          ? OutlinedButton.icon(
              onPressed: () {
                // clearing the field fires the listener → debounced reload from server
                searchController.clear();
              },
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Sa.accent,
                minimumSize: const Size(0, 46),
                side: const BorderSide(color: Sa.accent, width: 1.5),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadius12),
              ),
            )
          : null,
    );
  }

  Widget buildOrgsList() {
    // The server returns a capped, already-filtered page (search to narrow), so
    // there's no client-side "load more".
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      itemCount: filteredOrgs.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, index) => buildOrgCard(filteredOrgs[index], index),
    );
  }

  Widget buildOrgCard(Organisation organisation, int index) {
    final bool isInactive = !organisation.isActive;

    return SaCard(
      onTap: isInactive
          ? () => _showInactiveOrgMessage()
          : () => selectOrg(organisation),
      padding: const EdgeInsets.all(14),
      child: Opacity(
        opacity: isInactive ? 0.7 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isInactive
                    ? AppTheme.neutral100
                    : Sa.accent.withValues(alpha: 0.12),
                borderRadius: AppTheme.borderRadius12,
              ),
              child: Icon(
                Icons.apartment_rounded,
                size: 24,
                color: isInactive ? AppTheme.neutral500 : Sa.accent,
              ),
            ),
            const SizedBox(width: Sa.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          organisation.name,
                          style: Sa.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isInactive) ...[
                        const SizedBox(width: Sa.gapXs),
                        const SaStatusPill(
                          text: 'Inactive',
                          color: AppTheme.error,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    organisation.address,
                    style: Sa.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (organisation.headName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Head: ${organisation.headName}',
                      style: Sa.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: Sa.gapXs),
                  Wrap(
                    spacing: Sa.gapXs,
                    runSpacing: Sa.gapXs,
                    children: [
                      buildStatChip(
                        Icons.people_outline,
                        '${organisation.totalStudents} students',
                      ),
                      buildStatChip(
                        Icons.category_outlined,
                        organisation.orgType,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isInactive) ...[
              const SizedBox(width: Sa.gapXs),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Sa.accent.withValues(alpha: 0.10),
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Sa.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Sa.accent.withValues(alpha: 0.10),
        borderRadius: AppTheme.borderRadius8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Sa.accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: AppTheme.interFontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Sa.accent,
            ),
          ),
        ],
      ),
    );
  }

  void _showInactiveOrgMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This organisation is currently inactive. Contact your administrator.',
        ),
        backgroundColor: AppTheme.neutral800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.borderRadius8,
        ),
        margin: EdgeInsets.all(8),
      ),
    );
  }

  /// Opens the phone+password login as a card IN PLACE (dialog), not a new page.
  /// Direct sign-in: phone + password with no organisation pre-selected. The backend
  /// authenticates by phone and derives the organisation from the user's record, so
  /// this works for every role (and for admins who have no organisation yet).
  void _openDirectLogin() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: LoginCard(
            roleLabel: 'Sign in',
            onClose: () => Navigator.of(ctx).pop(),
            onSuccess: () {
              Navigator.of(ctx).pop();
              context.go(AuthSession.instance.landingRoute());
            },
          ),
        ),
      ),
    );
  }

  void _openLoginCard(Organisation organisation, [String? roleLabel]) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: LoginCard(
            name: organisation.name,
            roleLabel: roleLabel,
            organisationId: organisation.id,
            onClose: () => Navigator.of(ctx).pop(),
            onSuccess: () {
              Navigator.of(ctx).pop();
              context.go(AuthSession.instance.landingRoute());
            },
          ),
        ),
      ),
    );
  }

  void selectOrg(Organisation organisation) {
    final maxW = MediaQuery.of(context).size.width - 24;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        backgroundColor: Sa.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sa.radius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxW > 360 ? 360 : maxW,
            maxHeight: MediaQuery.of(context).size.height - 80,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppTheme.neutral600,
                    ),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Sa.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Sa.radius),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Sa.accent.withValues(alpha: 0.12),
                          borderRadius: AppTheme.borderRadius12,
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          size: 26,
                          color: Sa.accent,
                        ),
                      ),
                      const SizedBox(height: Sa.gapXs),
                      Text(
                        organisation.name,
                        style: Sa.cardTitle.copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (organisation.code != null) ...[
                        const SizedBox(height: Sa.gapXs),
                        SaStatusPill(
                          text: 'Organisation Code: ${organisation.code}',
                          icon: Icons.tag_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Sa.gap),
                // Login is by phone + password; the server resolves the user's role
                // from their identity, so there is no role to pick here (and there
                // is no teacher/student role — see SYSTEM_ARCHITECTURE.md).
                buildRoleOption(
                  'Sign in to this organisation',
                  Icons.login_rounded,
                  () {
                    Navigator.pop(context);
                    _openLoginCard(organisation);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRoleOption(String role, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius12,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Sa.accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(Sa.radius),
            border: Border.all(color: Sa.accent.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Sa.accent.withValues(alpha: 0.12),
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Icon(
                  icon,
                  color: Sa.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: Sa.gap),
              Expanded(
                child: Text(
                  role,
                  style: Sa.value,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Sa.accent,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
