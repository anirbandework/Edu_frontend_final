// lib/shared/widgets/navigation_sidebar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/auth/permission_store.dart';
import '../../core/auth/auth_session.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/org_session.dart';
import '../../services/profile_service.dart';

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
  final String? organisationId;
  final VoidCallback onClose;
  final VoidCallback onLogout;

  const NavigationSidebar({
    super.key,
    required this.isOpen,
    required this.userRole,
    this.userId,
    this.organisationId,
    required this.onClose,
    required this.onLogout,
  });

  @override
  State<NavigationSidebar> createState() => _NavigationSidebarState();
}

class _NavigationSidebarState extends State<NavigationSidebar>
    with SingleTickerProviderStateMixin {
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

  Future<void> _loadUserData() async {
    if (widget.userId == null) return;

    setState(() {
      _isLoadingUserData = true;
    });

    try {
      // The universal /api/auth/profile returns the caller's own first/last name
      // for EVERY role (super-admin, authority, staff) — so the sidebar name shows
      // for all of them, not just admins (super-admin used to be stuck on "Loading…").
      final userData = await ProfileService.getMyProfile();

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
    // opens a granted page (e.g. /authority/students). Honour the live
    // session role so staff always get THEIR dynamic sidebar (+ Home), never the
    // host shell's static menu.
    final effectiveRole =
        (AuthSession.instance.role == 'staff') ? 'staff' : widget.userRole.toLowerCase();
    switch (effectiveRole) {
      case 'admin':
      case 'authority':
        return [
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
            id: 'profile',
            label: 'Profile',
            icon: Icons.person,
            path: AppConstants.adminProfileRoute,
          ),
        ];

      case 'super_admin':
      case 'global_admin':
      case 'organisation_manager':
        return [
          NavigationItem(
            id: 'organisation-management',
            label: 'Institution Groups',
            icon: Icons.workspaces_outline,
            path: AppConstants.organisationManagementRoute,
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
        // Unified dynamic-role user: the sidebar IS their granted page set
        // (currently just Profile, appended below).
        final dyn = <NavigationItem>[];
        for (final m in PermissionStore.instance.modules) {
          // 'profile' is appended below with the real staff route.
          if (!m.enabled || m.key == 'profile' || m.path.isEmpty) {
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
        widget.userRole.toLowerCase() == 'organisation_manager';
  }

  String _getRoleDisplayName() {
    switch (widget.userRole.toLowerCase()) {
      case 'super_admin':
      // global_admin / organisation_manager are legacy aliases for the one super-admin role.
      case 'global_admin':
      case 'organisation_manager':
        return 'SUPER ADMIN';
      case 'admin':
      case 'authority':
        return 'ADMIN';
      default:
        return widget.userRole.toUpperCase();
    }
  }

  String _getUserName() {
    if (_userData == null) {
      // Show "Loading…" only while actually fetching; on failure fall back to a
      // role label so it never gets permanently stuck on "Loading…".
      if (_isLoadingUserData) return 'Loading…';
      switch (widget.userRole.toLowerCase()) {
        case 'super_admin':
        case 'global_admin':
        case 'organisation_manager':
          return 'Super Admin';
        case 'admin':
        case 'authority':
          return 'Admin';
        default:
          return 'User';
      }
    }

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
    final name = _getUserName().trim();
    if (name == 'Loading...' || name == 'User' || name.isEmpty) return 'U';

    // Split on any whitespace and drop empty parts so names with double/trailing
    // spaces (e.g. "John  Doe") don't index into an empty string (RangeError).
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    final first = parts[0];
    return (first.length >= 2 ? first.substring(0, 2) : first).toUpperCase();
  }

  String _buildUrlWithParams(String path) {
    if (widget.userId == null || widget.organisationId == null) {
      return path;
    }

    final uri = Uri.parse(path);
    final params = Map<String, String>.from(uri.queryParameters);
    params['userId'] = widget.userId!;
    params['organisationId'] = widget.organisationId!;

    return uri.replace(queryParameters: params).toString();
  }

  // Map a nav item id to its RBAC module key (null = always show). Only the pages
  // that survive the strip-down exist in the catalog: profile, rbac_management,
  // staff. (Feature pages are re-added here as their modules are rebuilt.)
  static const Map<String, String> _navModule = {
    'rbac-management': 'rbac_management',
    'staff': 'staff',
    'profile': 'profile',
  };

  // Icons for the dynamic staff sidebar (keyed by catalog module key). Unlisted
  // keys fall back to Icons.widgets — add an entry per page as features return.
  static const Map<String, IconData> _staffNavIcons = {
    'profile': Icons.person,
    'rbac_management': Icons.admin_panel_settings,
    'staff': Icons.badge,
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
                  Icon(
                    item.icon,
                    color: isActive ? Colors.white : AppTheme.neutral600,
                    size: 16,
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
                          fontSize: 10,
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
                  child: Center(
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
                          fontSize: 11,
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
                              _isGlobalUser() ? Icons.public : Icons.apartment,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                _isGlobalUser()
                                    ? 'Global System'
                                    : OrgSession.name ?? 'Organisation',
                                style: const TextStyle(
                                  fontSize: 11,
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
                              fontSize: 12,
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
                  fontSize: 11,
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
