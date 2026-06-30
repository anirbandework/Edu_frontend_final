// lib/shared/widgets/navigation_header.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/org_session.dart';
import 'org_switcher.dart';
import '../../features/feedback/widgets/feedback_dialog.dart';

class NavigationHeader extends StatefulWidget {
  final VoidCallback onToggleSidebar;
  final String userRole;
  final String? organisationId;
  final VoidCallback onLogout;
  final String? userName;
  final String? name;
  final int notificationCount;

  const NavigationHeader({
    super.key,
    required this.onToggleSidebar,
    required this.userRole,
    this.organisationId,
    required this.onLogout,
    this.userName,
    this.name,
    this.notificationCount = 0,
  });

  @override
  State<NavigationHeader> createState() => _NavigationHeaderState();
}

class _NavigationHeaderState extends State<NavigationHeader> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getPortalTitle() {
    // 3 user types only: super_admin, authority (admin), staff. There is no
    // teacher/student role — a "Teacher" is a staff user with that role name.
    switch (widget.userRole.toLowerCase()) {
      case 'admin':
      case 'authority':
        return 'Admin Portal';
      case 'staff':
        return 'Staff Portal';
      case 'super_admin':
      // global_admin / organisation_manager are legacy aliases for the one super-admin role.
      case 'global_admin':
      case 'organisation_manager':
        return 'Super Admin';
      default:
        return 'EduAssist';
    }
  }

  bool _isGlobalUser() {
    final r = widget.userRole.toLowerCase();
    return r == 'super_admin' || r == 'global_admin' || r == 'organisation_manager';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 48,
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            boxShadow: [AppTheme.microShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // Hamburger Menu
                _buildMenuButton(context),
                
                const SizedBox(width: 6),
                
                // Logo and Title
                _buildLogoSection(context),
                
                const Spacer(),

                // Give feedback — available to every role.
                Tooltip(
                  message: 'Give feedback',
                  child: InkWell(
                    borderRadius: AppTheme.borderRadius8,
                    onTap: () => showFeedbackDialog(context),
                    child: const SizedBox(
                      width: 44, // ≥44px tap target (a11y)
                      height: 44,
                      child: Center(
                        child: Icon(Icons.feedback_outlined, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Admin organisation switcher (renders only for authority)
                const OrgSwitcher(),

                const SizedBox(width: 6),

                // Organisation Info - Always show
                _buildOrgInfo(context),

                const SizedBox(width: 6),
                
                // COMMENTED OUT: User Profile Avatar Section
                // _buildUserProfileAvatar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return Tooltip(
      message: 'Menu',
      child: InkWell(
        onTap: widget.onToggleSidebar,
        borderRadius: AppTheme.borderRadius8,
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44), // ≥44px tap target (a11y)
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          decoration: AppTheme.getMicroDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: const Icon(
            Icons.menu,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    return Row(
      children: [
        // Logo Container
        Container(
          width: 24,
          height: 24,
          decoration: AppTheme.getMicroDecoration(
            color: Colors.white,
            borderRadius: AppTheme.borderRadius8,
          ),
          child: Center(
            child: Text(
              'EA',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.greenPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        // Title (Hidden on very small screens)
        if (context.screenWidth > 320) ...[
          const SizedBox(width: 6),
          Text(
            _getPortalTitle(),
            style: AppTheme.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrgInfo(BuildContext context) {
    final sessionName = OrgSession.name;
    final widgetName = widget.name;

    final name = sessionName ?? widgetName ?? '—';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: AppTheme.getMicroDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: AppTheme.borderRadius8,
            ),
            child: Icon(
              _isGlobalUser() ? Icons.public : Icons.apartment,
              color: Colors.white,
              size: 12,
            ),
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.screenWidth * 0.25,
            ),
            child: Text(
              _isGlobalUser() ? 'Global System' : _shortenName(name),
              style: AppTheme.bodyMicro.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _shortenName(String name) {
    if (name.length <= 20) return name;
    return '${name.substring(0, 17)}...';
  }

  // COMMENTED OUT: User Profile Avatar Section
  /*
  Widget _buildUserProfileAvatar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: AppTheme.getMicroDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User Avatar
          Stack(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.borderRadius6,
                ),
                child: Center(
                  child: Text(
                    _getUserInitials(),
                    style: TextStyle(
                      fontSize: 8,
                      color: AppTheme.greenPrimary,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.bauhausFontFamily,
                    ),
                  ),
                ),
              ),
              if (widget.notificationCount > 0 && !context.isMobile)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: AppTheme.borderRadius8,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
            ],
          ),
          
          // User Info (Tablet/Desktop) - Show role only
          if (context.isTablet || context.isDesktop) ...[
            const SizedBox(width: 6),
            Text(
              _getRoleDisplayName(),
              style: TextStyle(
                fontSize: 7,
                color: Colors.white70,
                fontFamily: AppTheme.bauhausFontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
  */
}

// Enhanced version with breadcrumbs
class AdvancedNavigationHeader extends StatelessWidget {
  final VoidCallback onToggleSidebar;
  final String userRole;
  final String? organisationId;
  final VoidCallback onLogout;
  final String? userName;
  final String? name;
  final int notificationCount;
  final List<Widget>? additionalActions;
  final bool showBreadcrumbs;
  final List<String>? breadcrumbs;

  const AdvancedNavigationHeader({
    super.key,
    required this.onToggleSidebar,
    required this.userRole,
    this.organisationId,
    required this.onLogout,
    this.userName,
    this.name,
    this.notificationCount = 0,
    this.additionalActions,
    this.showBreadcrumbs = false,
    this.breadcrumbs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NavigationHeader(
          onToggleSidebar: onToggleSidebar,
          userRole: userRole,
          organisationId: organisationId,
          onLogout: onLogout,
          userName: userName,
          name: name,
          notificationCount: notificationCount,
        ),
        
        // Breadcrumbs Section
        if (showBreadcrumbs && breadcrumbs != null && breadcrumbs!.isNotEmpty)
          Container(
            height: 32,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.green50,
              border: Border(
                bottom: BorderSide(color: AppTheme.neutral200.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.home,
                  size: 12,
                  color: AppTheme.greenPrimary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: breadcrumbs!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final breadcrumb = entry.value;
                        final isLast = index == breadcrumbs!.length - 1;
                        
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              breadcrumb,
                              style: AppTheme.bodyMicro.copyWith(
                                color: isLast ? AppTheme.greenPrimary : AppTheme.neutral600,
                                fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (!isLast) ...[
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.chevron_right,
                                size: 10,
                                color: AppTheme.neutral400,
                              ),
                              const SizedBox(width: 3),
                            ],
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (additionalActions != null) ...additionalActions!,
              ],
            ),
          ),
      ],
    );
  }
}
