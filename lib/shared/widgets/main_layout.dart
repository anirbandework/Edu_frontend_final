// lib/shared/widgets/main_layout.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/responsive.dart';
import 'navigation_header.dart';
import 'navigation_sidebar.dart';
import '../../core/utils/school_authority_session.dart';
import '../../core/utils/school_session.dart';
import '../../core/utils/student_session.dart';
import '../../core/utils/teacher_session.dart';
import '../../core/auth/auth_session.dart';
import '../../services/auth_api_service.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String userRole;
  final String? tenantId;
  final String? userId;
  final String? userName;
  final String? schoolName;
  final bool showBreadcrumbs;
  final List<String>? breadcrumbs;
  final List<Widget>? headerActions;
  final Color? backgroundColor;
  final bool isScrollable;

  const MainLayout({
    super.key,
    required this.child,
    required this.userRole,
    this.tenantId,
    this.userId,
    this.userName,
    this.schoolName,
    this.showBreadcrumbs = false,
    this.breadcrumbs,
    this.headerActions,
    this.backgroundColor,
    this.isScrollable = true,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isSidebarOpen = false;
  bool _isInitialized = false;
  bool? _wasMobile;
  late AnimationController _overlayController;
  late Animation<double> _overlayAnimation;
  int _notificationCount = 0;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  // Hydrate session stores SYNCHRONOUSLY (before any child screen's initState
  // runs) from AuthSession + the widget's role/identity, so dashboards/dialogs
  // that read the legacy static session holders never see null after login.
  _hydrateSessions();
  _setupAnimations();
  _loadInitialData();

  // After first frame: second-chance hydration from route query params (covers
  // the rare case where AuthSession is empty but the URL carries identity), then
  // set the initial sidebar state.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      final uri = GoRouterState.of(context).uri;
      _hydrateSessions(
        fallbackUserId: uri.queryParameters['userId'],
        fallbackTenantId: uri.queryParameters['tenantId'],
      );
    } catch (_) {
      // no-op: GoRouterState may be unavailable in some contexts
    }

    if (mounted && !_isInitialized) {
      setState(() {
        _isSidebarOpen = !context.isMobile;
        _wasMobile = context.isMobile;
        _isInitialized = true;
      });
    }
  });
}

/// Populate the legacy per-role static session holders from AuthSession (the
/// single source of truth), preferring the widget's own role/identity and
/// falling back to provided values. Idempotent — only fills what's empty.
void _hydrateSessions({String? fallbackUserId, String? fallbackTenantId}) {
  final auth = AuthSession.instance;
  final userId = (auth.userId?.isNotEmpty == true)
      ? auth.userId!
      : (widget.userId?.isNotEmpty == true ? widget.userId! : (fallbackUserId ?? ''));
  final tenantId = (auth.tenantId?.isNotEmpty == true)
      ? auth.tenantId!
      : (widget.tenantId?.isNotEmpty == true ? widget.tenantId! : (fallbackTenantId ?? ''));
  final role = (auth.role?.isNotEmpty == true) ? auth.role! : widget.userRole;
  if (userId.isEmpty || tenantId.isEmpty) return;

  if ((AuthoritySession.authorityId ?? '').isEmpty) {
    AuthoritySession.setSession(authorityId: userId, tenantId: tenantId);
  }
  if (SchoolSession.tenantId == null) {
    SchoolSession.setSchoolData(
        schoolName: 'School', schoolId: tenantId, tenantId: tenantId);
  }
  if (role == 'student' && !StudentSession.hasValidSession) {
    StudentSession.setSession(studentId: userId, tenantId: tenantId);
  }
  if (role == 'teacher' && !TeacherSession.hasValidSession) {
    TeacherSession.setSession(teacherId: userId, tenantId: tenantId);
  }
}


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Handle screen size changes (rotation, window resize). Only adjust the
    // sidebar state when crossing the mobile/desktop boundary, so a user's
    // manual toggle isn't overridden on every metrics change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isInitialized) {
        final isMobile = context.isMobile;
        if (_wasMobile != isMobile) {
          _wasMobile = isMobile;
          final shouldBeOpen = !isMobile;
          if (_isSidebarOpen != shouldBeOpen) {
            setState(() {
              _isSidebarOpen = shouldBeOpen;
            });
          }
        }
      }
    });
  }

  void _setupAnimations() {
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _overlayAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _overlayController, curve: Curves.easeOut),
    );
  }

  Future<void> _loadInitialData() async {
    // Load initial data. Notification count defaults to 0 until a real
    // count is wired up; no fabricated role-based badge.
    try {
      // Intentionally left without a fake notification count.
    } catch (e) {
      // Handle error silently
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });

    // Handle overlay animation for mobile
    if (context.isMobile) {
      if (_isSidebarOpen) {
        _overlayController.forward();
      } else {
        _overlayController.reverse();
      }
    }
  }

  void _closeSidebar() {
    if (_isSidebarOpen) {
      setState(() {
        _isSidebarOpen = false;
      });

      if (context.isMobile) {
        _overlayController.reverse();
      }
    }
  }

  void _handleLogout() {
    // Show confirmation dialog
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => _buildLogoutDialog(),
    ).then((confirmed) {
      if (confirmed == true) {
        // Revoke the token server-side + clear the local session, then go home.
        AuthApiService.logout();
        if (mounted) context.go(AppConstants.homeRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final sidebarWidth = context.isMobile ? 240.0 : 260.0;
    final backgroundColor =
        widget.backgroundColor ?? AppTheme.backgroundPrimary;

    return Material(
      color: backgroundColor,
      child: SafeArea(
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: Column(
            children: [
              // Ultra-Compact Navigation Header
              NavigationHeader(
                onToggleSidebar: _toggleSidebar,
                userRole: widget.userRole,
                tenantId: widget.tenantId,
                onLogout: _handleLogout,
                userName: widget.userName,
                schoolName: widget.schoolName,
                notificationCount: _notificationCount,
              ),

              // Micro Breadcrumbs Section
              if (widget.showBreadcrumbs && widget.breadcrumbs != null)
                _buildMicroBreadcrumbs(),

              // Main Content Area
              Expanded(
                child: Stack(
                  children: [
                    // Main Content with proper constraints
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      left: _isSidebarOpen && !context.isMobile
                          ? sidebarWidth
                          : 0,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          boxShadow: _isSidebarOpen && !context.isMobile
                              ? [AppTheme.microShadow]
                              : null,
                        ),
                        child: _buildConstrainedContent(),
                      ),
                    ),

                    // Mobile Overlay
                    if (_isSidebarOpen && context.isMobile)
                      AnimatedBuilder(
                        animation: _overlayAnimation,
                        builder: (context, child) {
                          return GestureDetector(
                            onTap: _closeSidebar,
                            child: Container(
                              color: AppTheme.surfaceOverlay.withOpacity(
                                _overlayAnimation.value * 0.5,
                              ),
                            ),
                          );
                        },
                      ),

                    // Ultra-Compact Sidebar
                    NavigationSidebar(
                      isOpen: _isSidebarOpen,
                      userRole: widget.userRole,
                      userId: widget.userId,
                      tenantId: widget.tenantId,
                      onClose: _closeSidebar,
                      onLogout: _handleLogout,
                    ),

                    // Micro FAB (Mobile)
                    if (context.isMobile && !_isSidebarOpen && _shouldShowFAB())
                      _buildMicroFAB(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicroBreadcrumbs() {
    return Container(
      height: 28,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.green50,
        border: Border(
          bottom: BorderSide(color: AppTheme.neutral200.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.home, size: 12, color: AppTheme.greenPrimary),
          const SizedBox(width: 4),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.breadcrumbs!.length,
              itemBuilder: (context, index) {
                final breadcrumb = widget.breadcrumbs![index];
                final isLast = index == widget.breadcrumbs!.length - 1;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      breadcrumb,
                      style: AppTheme.bodyMicro.copyWith(
                        color: isLast
                            ? AppTheme.greenPrimary
                            : AppTheme.neutral600,
                        fontWeight: isLast
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (!isLast) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.chevron_right,
                        size: 10,
                        color: AppTheme.neutral400,
                      ),
                      const SizedBox(width: 3),
                    ],
                  ],
                );
              },
            ),
          ),
          if (widget.headerActions != null) ...widget.headerActions!,
        ],
      ),
    );
  }

  Widget _buildConstrainedContent() {
    // final screenHeight = MediaQuery.of(context).size.height;
    // final safe =
    //     MediaQuery.of(context).padding.top +
    //     MediaQuery.of(context).padding.bottom;
    // final headerH = 48;
    // final crumbH = widget.showBreadcrumbs && widget.breadcrumbs != null
    //     ? 28
    //     : 0;
    // final availableHeight = screenHeight - safe - headerH - crumbH;

    return FocusTraversalGroup(
    child: CustomScrollView(
      primary: false,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverFillRemaining(
            hasScrollBody: true,
            child: widget.child,
          ),
        ),
      ],
    ),
  );
}

  bool _shouldShowFAB() {
    // Show floating menu button based on user role
    return [
      'admin',
      'teacher',
      'school_authority',
    ].contains(widget.userRole.toLowerCase());
  }

  Widget _buildMicroFAB() {
    return Positioned(
      bottom: 16,
      right: 12,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.greenPrimary,
          borderRadius: AppTheme.borderRadius8,
          boxShadow: [
            BoxShadow(
              color: AppTheme.greenPrimary.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: InkWell(
          onTap: _toggleSidebar,
          borderRadius: AppTheme.borderRadius8,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              _isSidebarOpen ? Icons.close : Icons.menu,
              key: ValueKey(_isSidebarOpen),
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: context.isMobile ? context.screenWidth * 0.85 : 320,
        decoration: AppTheme.getMicroDecoration(
          color: Colors.white,
          borderRadius: AppTheme.borderRadius12,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: AppTheme.borderRadius8,
              ),
              child: Icon(Icons.logout, size: 24, color: AppTheme.error),
            ),

            const SizedBox(height: 12),

            Text(
              'Confirm Logout',
              style: AppTheme.headingSmall.copyWith(color: AppTheme.neutral900),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 6),

            Text(
              'Are you sure you want to logout? You will need to sign in again to access your account.',
              style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral600),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTheme.bodyMicro.copyWith(
                        color: AppTheme.neutral600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(
                      'Logout',
                      style: AppTheme.bodyMicro.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced layout with additional features
class AdvancedMainLayout extends StatelessWidget {
  final Widget child;
  final String userRole;
  final String? tenantId;
  final String? userId;
  final String? userName;
  final String? schoolName;
  final bool showBreadcrumbs;
  final List<String>? breadcrumbs;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;

  const AdvancedMainLayout({
    super.key,
    required this.child,
    required this.userRole,
    this.tenantId,
    this.userId,
    this.userName,
    this.schoolName,
    this.showBreadcrumbs = false,
    this.breadcrumbs,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      userRole: userRole,
      tenantId: tenantId,
      userId: userId,
      userName: userName,
      schoolName: schoolName,
      showBreadcrumbs: showBreadcrumbs,
      breadcrumbs: breadcrumbs,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            child,
            if (floatingActionButton != null)
              Positioned(
                bottom: bottomNavigationBar != null ? 80 : 16,
                right: 16,
                child: floatingActionButton!,
              ),
            if (bottomNavigationBar != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: bottomNavigationBar!,
              ),
          ],
        ),
      ),
    );
  }
}

// Compact layout for simple pages
class CompactMainLayout extends StatelessWidget {
  final Widget child;
  final String userRole;
  final String title;
  final List<Widget>? actions;

  const CompactMainLayout({
    super.key,
    required this.child,
    required this.userRole,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      userRole: userRole,
      showBreadcrumbs: true,
      breadcrumbs: [title],
      headerActions: actions,
      isScrollable: false,
      child: child,
    );
  }
}

// Micro layout for minimal screens
class MicroMainLayout extends StatelessWidget {
  final Widget child;
  final String userRole;
  final String? title;

  const MicroMainLayout({
    super.key,
    required this.child,
    required this.userRole,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.backgroundPrimary,
      child: SafeArea(
        child: Column(
          children: [
            // Micro header
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                boxShadow: [AppTheme.microShadow],
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: AppTheme.getMicroDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.borderRadius8,
                    ),
                    child: Center(
                      child: Text(
                        'EA',
                        style: AppTheme.bodyMicro.copyWith(
                          color: AppTheme.greenPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      title!,
                      style: AppTheme.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
