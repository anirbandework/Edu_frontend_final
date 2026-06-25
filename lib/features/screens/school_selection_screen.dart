// lib/features/screens/school_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/models/tenant.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../../shared/widgets/login_card.dart';
import '../../core/auth/auth_session.dart';
import '../../services/tenant_management_service.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController searchController = TextEditingController();
  List<Tenant> schools = [];
  List<Tenant> filteredSchools = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? error;
  int currentPage = 1;
  final int pageSize = 50;
  bool hasMoreData = true;
  bool includeInactive = false;

  AnimationController? animationController;
  Animation<double>? fadeAnimation;
  Animation<Offset>? slideAnimation;

  @override
  void initState() {
    super.initState();
    setupAnimations();
    searchController.addListener(filterSchools);
    WidgetsBinding.instance.addPostFrameCallback((_) => loadSchools());
  }

  @override
  void dispose() {
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

  Future<void> loadSchools([bool refresh = false]) async {
    if (!mounted) return;
    
    if (refresh) {
      currentPage = 1;
      hasMoreData = true;
      schools.clear();
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
      final newSchools = await TenantService.getPublicSchools();

      if (!mounted) return;

      schools = newSchools;
      hasMoreData = false; // public endpoint returns all active schools at once

      filteredSchools = schools;

      if (searchController.text.isNotEmpty) {
        filterSchools();
      }
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

  Future<void> loadMoreSchools() async {
    if (!hasMoreData || isLoadingMore) return;
    await loadSchools();
  }

  void filterSchools() {
    if (!mounted) return;
    
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredSchools = schools.where((school) {
        return school.schoolName.toLowerCase().contains(query) ||
               school.address.toLowerCase().contains(query) ||
               school.principalName.toLowerCase().contains(query);
      }).toList();
    });
  }

  void toggleIncludeInactive() {
    setState(() {
      includeInactive = !includeInactive;
    });
    loadSchools(true);
  }

  @override
  Widget build(BuildContext context) {
    if (animationController == null || fadeAnimation == null || slideAnimation == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundPrimary,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: buildAppBar(),
      body: FadeTransition(
        opacity: fadeAnimation!,
        child: SlideTransition(
          position: slideAnimation!,
          child: Column(
            children: [
              buildSearchSection(),
              if (includeInactive) buildInactiveInfo(),
              Expanded(
                child: isLoading
                    ? buildLoadingState()
                    : error != null
                        ? buildErrorState()
                        : filteredSchools.isEmpty
                            ? buildEmptyState()
                            : buildSchoolsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
      ),
      toolbarHeight: 40, // Reduced from 48
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 18, // Reduced
        ),
        onPressed: () => context.go(AppConstants.homeRoute),
      ),
      title: Text(
        'Select School',
        style: AppTheme.headingSmall.copyWith(
          color: Colors.white,
          fontSize: 16, // Reduced
        ),
      ),
      actions: [
        // Sign in directly with phone + password (no school needed). The backend
        // resolves the school from the user's phone, so admins (who may have no
        // school yet) and everyone else can log in straight away.
        TextButton.icon(
          onPressed: _openDirectLogin,
          icon: const Icon(Icons.login, color: Colors.white, size: 16),
          label: Text('Sign in',
              style: AppTheme.labelSmall.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          icon: Icon(
            includeInactive ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
            size: 18, // Reduced
          ),
          onPressed: toggleIncludeInactive,
          tooltip: includeInactive ? 'Hide Inactive Schools' : 'Show Inactive Schools',
        ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: Colors.white,
            size: 18, // Reduced
          ),
          onPressed: () => loadSchools(true),
        ),
        const SizedBox(width: 8), // Reduced
      ],
    );
  }

  Widget buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(8), // Reduced
      decoration: const BoxDecoration(
        gradient: AppTheme.glassGreenGradient,
        border: Border(
          bottom: BorderSide(color: AppTheme.neutral200, width: 0.5),
        ),
      ),
      child: SearchBarWidget(
        controller: searchController,
        hintText: 'Search schools by name, address, or principal...',
      ),
    );
  }

  Widget buildInactiveInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced
      padding: const EdgeInsets.all(8), // Reduced
      decoration: AppTheme.getGlassDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.warning,
            size: 14, // Reduced
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing active and inactive schools',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.warning,
                fontSize: 11, // Reduced
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16), // Reduced
            decoration: BoxDecoration(
              color: AppTheme.greenPrimary.withOpacity(0.1),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: const CircularProgressIndicator(
              color: AppTheme.greenPrimary,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading schools...',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.neutral600,
              fontSize: 12, // Reduced
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16), // Reduced
        padding: const EdgeInsets.all(16), // Reduced
        decoration: AppTheme.getGlassDecoration(
          color: AppTheme.error.withOpacity(0.1),
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12), // Reduced
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: AppTheme.borderRadius12,
              ),
              child: Icon(
                Icons.error_outline,
                size: 28, // Reduced
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Oops! Something went wrong',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.error,
                fontSize: 14, // Reduced
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.neutral600,
                fontSize: 11, // Reduced
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: AppTheme.borderRadius8,
                boxShadow: [AppTheme.cardShadow],
              ),
              child: ElevatedButton(
                onPressed: () => loadSchools(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 14), // Reduced
                    const SizedBox(width: 6),
                    Text(
                      'Try Again',
                      style: AppTheme.labelMedium.copyWith(
                        color: Colors.white,
                        fontSize: 11, // Reduced
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16), // Reduced
        padding: const EdgeInsets.all(16), // Reduced
        decoration: AppTheme.getGlassDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16), // Reduced
              decoration: BoxDecoration(
                color: AppTheme.neutral100,
                borderRadius: AppTheme.borderRadius12,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 32, // Reduced
                color: AppTheme.neutral400,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No schools found',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.neutral600,
                fontSize: 14, // Reduced
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              searchController.text.isNotEmpty
                  ? 'Try adjusting your search terms or clear the search to see all schools.'
                  : includeInactive
                      ? 'No schools are currently available.'
                      : 'Try including inactive schools to see more results.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.neutral500,
                fontSize: 11, // Reduced
              ),
              textAlign: TextAlign.center,
            ),
            if (searchController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  searchController.clear();
                  filterSchools();
                },
                style: AppTheme.textButtonStyle.copyWith(
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced
                  ),
                ),
                child: Text(
                  'Clear Search',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.greenPrimary,
                    fontSize: 11, // Reduced
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildSchoolsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced
      itemCount: filteredSchools.length + (hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredSchools.length) {
          return buildLoadMoreWidget();
        }
        final school = filteredSchools[index];
        return buildSchoolCard(school, index);
      },
    );
  }

  Widget buildLoadMoreWidget() {
    if (isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(12), // Reduced
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16, // Reduced
              height: 16, // Reduced
              child: const CircularProgressIndicator(
                color: AppTheme.greenPrimary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading more schools...',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.neutral600,
                fontSize: 11, // Reduced
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(8), // Reduced
      child: OutlinedButton(
        onPressed: loadMoreSchools,
        style: AppTheme.outlineButtonStyle.copyWith(
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 10), // Reduced
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.expand_more, size: 16), // Reduced
            const SizedBox(width: 6),
            Text(
              'Load More Schools',
              style: AppTheme.labelMedium.copyWith(
                fontSize: 11, // Reduced
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSchoolCard(Tenant school, int index) {
    final bool isInactive = !school.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 6), // Reduced
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInactive
              ? () => _showInactiveSchoolMessage()
              : () => selectSchool(school),
          borderRadius: AppTheme.borderRadius8,
          child: Container(
            padding: const EdgeInsets.all(10), // Reduced
            decoration: AppTheme.getGlassDecoration(
              color: isInactive 
                  ? AppTheme.neutral50.withOpacity(0.5)
                  : AppTheme.surfacePrimary,
              border: Border.all(
                color: isInactive ? AppTheme.neutral300 : AppTheme.neutral200,
                width: 0.5,
              ),
            ),
            child: Opacity(
              opacity: isInactive ? 0.6 : 1.0,
              child: Row(
                children: [
                  Container(
                    width: 36, // Reduced
                    height: 36, // Reduced
                    decoration: AppTheme.getGlassDecoration(
                      color: isInactive ? AppTheme.neutral300 : AppTheme.green50,
                      borderRadius: AppTheme.borderRadius8,
                    ),
                    child: Icon(
                      Icons.school,
                      size: 20, // Reduced
                      color: isInactive ? AppTheme.neutral600 : AppTheme.greenPrimary,
                    ),
                  ),
                  const SizedBox(width: 10), // Reduced
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                school.schoolName,
                                style: AppTheme.labelMedium.copyWith(
                                  fontSize: 13, // Reduced
                                  fontWeight: FontWeight.bold,
                                  color: isInactive ? AppTheme.neutral600 : AppTheme.neutral900,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isInactive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.1),
                                  borderRadius: AppTheme.borderRadius8,
                                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'Inactive',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontSize: 8, // Reduced
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4), // Reduced
                        Text(
                          school.address,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.neutral600,
                            fontSize: 10, // Reduced
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (school.principalName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Principal: ${school.principalName}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.neutral500,
                              fontSize: 9, // Reduced
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            buildStatChip(
                              Icons.people,
                              '${school.totalStudents} students',
                              AppTheme.info,
                            ),
                            const SizedBox(width: 6),
                            buildStatChip(
                              Icons.category,
                              school.schoolType,
                              AppTheme.greenPrimary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isInactive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6), // Reduced
                      decoration: BoxDecoration(
                        color: AppTheme.green50,
                        borderRadius: AppTheme.borderRadius8,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 12, // Reduced
                        color: AppTheme.greenPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppTheme.borderRadius8,
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color), // Reduced
          const SizedBox(width: 3),
          Text(
            text,
            style: AppTheme.bodySmall.copyWith(
              fontSize: 8, // Reduced
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showInactiveSchoolMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This school is currently inactive. Contact your administrator.',
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.borderRadius8,
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  /// Opens the phone+password login as a card IN PLACE (dialog), not a new page.
  /// Direct sign-in: phone + password with no school pre-selected. The backend
  /// authenticates by phone and derives the school from the user's record, so
  /// this works for every role (and for admins who have no school yet).
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
            onForgot: () {
              Navigator.of(ctx).pop();
              context.go(AppConstants.forgotPasswordRoute);
            },
            onSuccess: () {
              Navigator.of(ctx).pop();
              context.go(AuthSession.instance.landingRoute());
            },
          ),
        ),
      ),
    );
  }

  void _openLoginCard(Tenant school, String roleLabel) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: LoginCard(
            schoolName: school.schoolName,
            roleLabel: roleLabel,
            tenantId: school.id,
            onClose: () => Navigator.of(ctx).pop(),
            onForgot: () {
              Navigator.of(ctx).pop();
              context.go(AppConstants.forgotPasswordRoute);
            },
            onSuccess: () {
              Navigator.of(ctx).pop();
              context.go(AuthSession.instance.landingRoute());
            },
          ),
        ),
      ),
    );
  }

  void selectSchool(Tenant school) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: context.isMobile ? context.screenWidth * 0.9 : 320, // Reduced
          decoration: AppTheme.getGlassDecoration(
            borderRadius: AppTheme.borderRadius12,
          ),
          padding: const EdgeInsets.all(16), // Reduced
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.neutral600,
                  ),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12), // Reduced
                decoration: const BoxDecoration(
                  gradient: AppTheme.glassGreenGradient,
                  borderRadius: AppTheme.borderRadius12,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.school,
                      size: 24, // Reduced
                      color: AppTheme.greenPrimary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      school.schoolName,
                      style: AppTheme.headingSmall.copyWith(
                        fontSize: 14, // Reduced
                        color: AppTheme.neutral900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (school.schoolCode != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced
                        decoration: BoxDecoration(
                          color: AppTheme.info.withOpacity(0.1),
                          borderRadius: AppTheme.borderRadius8,
                          border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                        ),
                        child: Text(
                          'School Code: ${school.schoolCode}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.info,
                            fontSize: 9, // Reduced
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select Your Role',
                style: AppTheme.labelMedium.copyWith(
                  fontSize: 12, // Reduced
                  color: AppTheme.neutral800,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  buildRoleOption(
                    'Student',
                    Icons.person,
                    AppTheme.info,
                    () {
                      Navigator.pop(context);
                      _openLoginCard(school, 'Student');
                    },
                  ),
                  const SizedBox(height: 8),
                  buildRoleOption(
                    'Teacher',
                    Icons.person_2,
                    AppTheme.success,
                    () {
                      Navigator.pop(context);
                      _openLoginCard(school, 'Teacher');
                    },
                  ),
                  const SizedBox(height: 8),
                  buildRoleOption(
                    'School Authority',
                    Icons.admin_panel_settings,
                    AppTheme.warning,
                    () {
                      Navigator.pop(context);
                      _openLoginCard(school, 'School Authority');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRoleOption(String role, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius8,
        child: Container(
          padding: const EdgeInsets.all(10), // Reduced
          decoration: AppTheme.getGlassDecoration(
            color: color.withOpacity(0.05),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // Reduced
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16, // Reduced
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  role,
                  style: AppTheme.labelMedium.copyWith(
                    fontSize: 12, // Reduced
                    color: AppTheme.neutral800,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 12, // Reduced
              ),
            ],
          ),
        ),
      ),
    );
  }

}
