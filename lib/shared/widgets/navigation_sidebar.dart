// lib/shared/widgets/navigation_sidebar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/auth/permission_store.dart';
import '../../core/auth/auth_session.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/school_session.dart';
import '../../services/school_authority_service.dart';
import '../../services/notification_service.dart';

class NavigationItem {
  final String id;
  final String label;
  final IconData icon;
  final String path;
  final String? badge;
  final Color? badgeColor;

  NavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
    this.badge,
    this.badgeColor,
  });
}

class NavigationSidebar extends StatefulWidget {
  final bool isOpen;
  final String userRole;
  final String? userId;
  final String? tenantId;
  final VoidCallback onClose;
  final VoidCallback onLogout;

  const NavigationSidebar({
    super.key,
    required this.isOpen,
    required this.userRole,
    this.userId,
    this.tenantId,
    required this.onClose,
    required this.onLogout,
  });

  @override
  State<NavigationSidebar> createState() => _NavigationSidebarState();
}

class _NavigationSidebarState extends State<NavigationSidebar>
    with SingleTickerProviderStateMixin {
  int _unreadNotificationsCount = 0;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = false;

  // Rebuild the (dynamic, permission-driven) staff sidebar whenever permissions
  // load or change — otherwise a staff user can see only "Home" until a navigation.
  void _onPermissionsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
    _loadUserData();
    PermissionStore.instance.addListener(_onPermissionsChanged);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    if (widget.isOpen) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(NavigationSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }

    // Reload user data if userId changed
    if (widget.userId != oldWidget.userId) {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    PermissionStore.instance.removeListener(_onPermissionsChanged);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    if (widget.userId == null || widget.tenantId == null) return;
    // Map the UI role to the backend user_type; super-admin has no inbox.
    String? userType;
    switch (widget.userRole.toLowerCase()) {
      case 'admin':
      case 'school_authority':
        userType = 'school_authority';
        break;
    }
    if (userType == null) return;
    try {
      final unread = await NotificationService.getNotificationsForUser(
        userId: widget.userId!,
        userType: userType,
        tenantId: widget.tenantId!,
        unreadOnly: true,
        limit: 100,
      );
      if (mounted) {
        setState(() => _unreadNotificationsCount = unread.length);
      }
    } catch (_) {
      // Non-fatal: leave the badge at its current value.
    }
  }

  Future<void> _loadUserData() async {
    if (widget.userId == null) return;

    setState(() {
      _isLoadingUserData = true;
    });

    try {
      Map<String, dynamic>? userData;

      switch (widget.userRole.toLowerCase()) {
        case 'admin':
        case 'school_authority':
          userData = await AuthorityService.getAuthorityById(widget.userId!);
          break;
      }

      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoadingUserData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  List<NavigationItem> _getNavigationItems() {
    // A dynamic-staff session may render inside another role's ShellRoute when it
    // opens a granted page (e.g. /school_authority/students). Honour the live
    // session role so staff always get THEIR dynamic sidebar (+ Home), never the
    // host shell's static menu.
    final effectiveRole =
        (AuthSession.instance.role == 'staff') ? 'staff' : widget.userRole.toLowerCase();
    switch (effectiveRole) {
      case 'admin':
      case 'school_authority':
        return [
          NavigationItem(
            id: 'dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard,
            path: AppConstants.adminDashboardRoute,
          ),
          NavigationItem(
            id: 'notifications',
            label: 'Notifications',
            icon: Icons.notifications,
            path: AppConstants.adminNotificationsRoute,
            badge: _unreadNotificationsCount > 0
                ? _unreadNotificationsCount.toString()
                : null,
            badgeColor: AppTheme.error,
          ),
          NavigationItem(
            id: 'send-notification',
            label: 'Send Message',
            icon: Icons.send,
            path: AppConstants.adminSendNotificationRoute,
          ),
          // NEW: Classes management for school authorities
          NavigationItem(
            id: 'classes',
            label: 'Classes',
            icon: Icons.class_,
            path: '/school_authority/classes',
          ),
          NavigationItem(
            id: 'students',
            label: 'Students',
            icon: Icons.people,
            path: '/school_authority/students',
          ),
          NavigationItem(
            id: 'exams',
            label: 'Exams',
            icon: Icons.assignment,
            path: AppConstants.adminExamsRoute,
          ),
          NavigationItem(
            id: 'enrollment',
            label: 'Enrolment',
            icon: Icons.group_add,
            path: AppConstants.adminEnrollmentRoute,
          ),
          NavigationItem(
            id: 'rbac-management',
            label: 'Roles & Access',
            icon: Icons.admin_panel_settings,
            path: '/admin/roles',
          ),
          NavigationItem(
            id: 'staff',
            label: 'Staff & Users',
            icon: Icons.badge,
            path: AppConstants.adminStaffRoute,
          ),

          NavigationItem(
            id: 'attendance',
            label: 'Attendance',
            icon: Icons.how_to_reg,
            path: AppConstants.adminAttendanceRoute, // add this constant
          ),
          NavigationItem(
            id: 'timetable',
            label: 'Timetable',
            icon: Icons.schedule,
            path: '/school_authority/timetable',
          ),
          NavigationItem(
            id: 'profile',
            label: 'Profile',
            icon: Icons.person,
            path: AppConstants.adminProfileRoute,
          ),
          
        ];

      case 'super_admin':
      case 'global_admin':
      case 'tenant_manager':
        return [
          NavigationItem(
            id: 'tenant-management',
            label: 'Tenants',
            icon: Icons.business,
            path: AppConstants.tenantManagementRoute,
          ),
          NavigationItem(
            id: 'admins',
            label: 'Admins',
            icon: Icons.person_add_alt_1,
            path: AppConstants.superAdminAdminsRoute,
          ),
          NavigationItem(
            id: 'module-access',
            label: 'Module Access',
            icon: Icons.tune,
            path: AppConstants.superAdminModuleAccessRoute,
          ),
          NavigationItem(
            id: 'analytics',
            label: 'Analytics',
            icon: Icons.insights,
            path: AppConstants.superAdminAnalyticsRoute,
          ),
          NavigationItem(
            id: 'feedback',
            label: 'Feedback',
            icon: Icons.feedback,
            path: AppConstants.superAdminFeedbackRoute,
          ),
          NavigationItem(
            id: 'profile',
            label: 'Profile',
            icon: Icons.person,
            path: AppConstants.superAdminProfileRoute,
          ),
        ];

      case 'staff':
        // Unified dynamic-role user: the sidebar IS their granted page set.
        final dyn = <NavigationItem>[
          NavigationItem(
            id: 'staff-home',
            label: 'Home',
            icon: Icons.dashboard,
            path: AppConstants.staffDashboardRoute,
          ),
        ];
        for (final m in PermissionStore.instance.modules) {
          // 'profile' is appended below with the real staff route; 'dashboard'
          // is the Home tile above.
          if (!m.enabled || m.key == 'dashboard' || m.key == 'profile' || m.path.isEmpty) {
            continue;
          }
          dyn.add(NavigationItem(
            id: m.key,
            label: m.name.isEmpty ? m.key : m.name,
            icon: _staffNavIcons[m.key] ?? Icons.widgets,
            path: m.path,
          ));
        }
        // Profile is universal — always present for staff too.
        dyn.add(NavigationItem(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person,
          path: AppConstants.staffProfileRoute,
        ));
        return dyn;

      default:
        return [];
    }
  }

  bool _isGlobalUser() {
    return widget.userRole.toLowerCase() == 'global_admin' ||
        widget.userRole.toLowerCase() == 'tenant_manager';
  }

  String _getRoleDisplayName() {
    switch (widget.userRole.toLowerCase()) {
      case 'global_admin':
        return 'GLOBAL ADMIN';
      case 'tenant_manager':
        return 'TENANT MANAGER';
      case 'admin':
      case 'school_authority':
        return 'SCHOOL ADMIN';
      default:
        return widget.userRole.toUpperCase();
    }
  }

  String _getUserName() {
    if (_userData == null) return 'Loading...';

    final firstName = _userData!['first_name']?.toString() ?? '';
    final lastName = _userData!['last_name']?.toString() ?? '';

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }

    return 'User';
  }

  String _getUserInitials() {
    final name = _getUserName();
    if (name == 'Loading...' || name == 'User') return 'U';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name[0].toUpperCase();
  }

  String _buildUrlWithParams(String path) {
    if (widget.userId == null || widget.tenantId == null) {
      return path;
    }

    final uri = Uri.parse(path);
    final params = Map<String, String>.from(uri.queryParameters);
    params['userId'] = widget.userId!;
    params['tenantId'] = widget.tenantId!;

    return uri.replace(queryParameters: params).toString();
  }

  // Map a nav item id to its RBAC module key (null = always show).
  static const Map<String, String> _navModule = {
    'dashboard': 'dashboard',
    'notifications': 'notifications',
    'send-notification': 'send_notification',
    'classes': 'classes',
    'students': 'students',
    'attendance': 'attendance',
    'timetable': 'timetable',
    'enrollment': 'enrollment',
    'exams': 'exams',
    'assignments': 'assignments',
    'grades': 'grades',
    'quizzes': 'quizzes',
    'chat': 'chat',
    'profile': 'profile',
    'rbac-management': 'rbac_management',
    'staff': 'staff',
  };

  // Icons for the dynamic staff sidebar (keyed by catalog module key).
  static const Map<String, IconData> _staffNavIcons = {
    'profile': Icons.person,
    'notifications': Icons.notifications,
    'students': Icons.people,
    'classes': Icons.class_,
    'timetable': Icons.schedule,
    'attendance': Icons.how_to_reg,
    'send_notification': Icons.send,
    'exams': Icons.assignment,
    'rbac_management': Icons.admin_panel_settings,
    'staff': Icons.badge,
    'my_classes': Icons.class_,
    'assignments': Icons.assignment_turned_in,
    'grades': Icons.grade,
  };

  // Items that are ALWAYS shown, regardless of RBAC (every user has them).
  static const Set<String> _alwaysShow = {'profile', 'staff-home'};

  @override
  Widget build(BuildContext context) {
    // Gate by RBAC: hide items whose module the user's role has disabled —
    // except the always-on items (Profile is universal, never permission-gated).
    final items = _getNavigationItems()
        .where((it) =>
            _alwaysShow.contains(it.id) ||
            PermissionStore.instance.canModule(_navModule[it.id]))
        .toList();
    final currentLocation = GoRouterState.of(context).uri.toString();
    final screenSize = MediaQuery.of(context).size;
    final sidebarWidth = context.isMobile ? 240.0 : 260.0;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Positioned(
          left: widget.isOpen ? 0 : -sidebarWidth,
          top: 0,
          bottom: 0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: sidebarWidth,
              height: screenSize.height,
              decoration: AppTheme.getMicroDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(color: AppTheme.neutral200.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  if (_showQuickActions()) _buildQuickActions(context),
                  Expanded(
                    child: items.isEmpty
                        ? _buildEmptyState(context)
                        : _buildNavigationList(context, items, currentLocation),
                  ),
                  _buildUserSection(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _showQuickActions() {
    return (widget.userRole == 'admin' ||
            widget.userRole == 'school_authority' ||
            widget.userRole == 'teacher') &&
        !context.isMobile;
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.green50,
        border: Border(
          bottom: BorderSide(color: AppTheme.neutral200.withValues(alpha: 0.5)),
        ),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              context,
              icon: Icons.send,
              label: 'Send',
              onTap: () {
                final route = widget.userRole == 'teacher'
                    ? AppConstants.teacherSendNotificationRoute
                    : AppConstants.adminSendNotificationRoute;
                context.go(_buildUrlWithParams(route));
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildQuickActionButton(
              context,
              icon: Icons.notifications_active,
              label: 'View',
              badge: _unreadNotificationsCount > 0
                  ? _unreadNotificationsCount.toString()
                  : null,
              onTap: () {
                final route = widget.userRole == 'teacher'
                    ? AppConstants.teacherNotificationsRoute
                    : AppConstants.adminNotificationsRoute;
                context.go(_buildUrlWithParams(route));
              },
            ),
          ),
          if (widget.userRole == 'admin' ||
              widget.userRole == 'school_authority') ...[
            const SizedBox(width: 6),
            Expanded(
              child: _buildQuickActionButton(
                context,
                icon: Icons.class_,
                label: 'Classes',
                onTap: () {
                  context.go(_buildUrlWithParams('/school_authority/classes'));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: AppTheme.getMicroDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.neutral300.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: AppTheme.greenPrimary, size: 12),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: AppTheme.borderRadius8,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTheme.bodyMicro.copyWith(
                color: AppTheme.neutral700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationList(
    BuildContext context,
    List<NavigationItem> items,
    String currentLocation,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final targetUrl = _buildUrlWithParams(item.path);
        final isActive =
            Uri.parse(currentLocation).path == Uri.parse(targetUrl).path;

        return Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: InkWell(
            onTap: () {
              context.go(targetUrl);
              if (item.id == 'notifications') {
                setState(() {
                  _unreadNotificationsCount = 0;
                });
              }
            },
            borderRadius: AppTheme.borderRadius8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: isActive ? AppTheme.primaryGradient : null,
                color: !isActive ? Colors.transparent : null,
                borderRadius: AppTheme.borderRadius8,
                boxShadow: isActive ? [AppTheme.microShadow] : null,
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        item.icon,
                        color: isActive ? Colors.white : AppTheme.neutral600,
                        size: 16,
                      ),
                      if (item.id == 'notifications' &&
                          _unreadNotificationsCount > 0 &&
                          !isActive)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: AppTheme.borderRadius8,
                            ),
                            child: Text(
                              _unreadNotificationsCount > 9
                                  ? '9+'
                                  : _unreadNotificationsCount.toString(),
                              style: const TextStyle(
                                fontSize: 6,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTheme.bodyMicro.copyWith(
                        color: isActive ? Colors.white : AppTheme.neutral700,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.3)
                            : (item.badgeColor ?? AppTheme.error),
                        borderRadius: AppTheme.borderRadius8,
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          fontSize: 7,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.neutral100,
                borderRadius: AppTheme.borderRadius12,
              ),
              child: const Icon(Icons.menu, size: 32, color: AppTheme.neutral400),
            ),
            const SizedBox(height: 12),
            Text(
              'No navigation items',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.neutral600),
            ),
            const SizedBox(height: 6),
            Text(
              'No menu items available for your current role.',
              style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.neutral200.withValues(alpha: 0.5)),
        ),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.borderRadius8,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: _isLoadingUserData
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: AppTheme.greenPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _getUserInitials(),
                                style: AppTheme.labelSmall.copyWith(
                                  color: AppTheme.greenPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      if (_unreadNotificationsCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: AppTheme.borderRadius8,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Text(
                              _unreadNotificationsCount > 9
                                  ? '9+'
                                  : _unreadNotificationsCount.toString(),
                              style: const TextStyle(
                                fontSize: 6,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getUserName(),
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getRoleDisplayName(),
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white70,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: AppTheme.borderRadius8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isGlobalUser() ? Icons.public : Icons.school,
                              color: Colors.white,
                              size: 8,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                _isGlobalUser()
                                    ? 'Global System'
                                    : SchoolSession.schoolName ?? 'School',
                                style: const TextStyle(
                                  fontSize: 7,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: widget.onLogout,
                  borderRadius: AppTheme.borderRadius8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: AppTheme.borderRadius8,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.logout, color: Colors.white, size: 12),
                        if (!context.isMobile) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (context.isMobile) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: AppTheme.borderRadius8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 12,
                color: AppTheme.neutral500,
              ),
              SizedBox(width: 4),
              Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 8,
                  color: AppTheme.neutral500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
