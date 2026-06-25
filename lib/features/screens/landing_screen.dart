// lib/features/tenant_management/screens/landing_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/auth/auth_session.dart';
import '../../shared/widgets/login_card.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: ResponsiveContainer(
            maxWidth: context.responsive(ResponsiveSize.maxContentWidth),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: context.isMobile ? 30 : 20),

                      _buildHeaderSection(context),

                      SizedBox(height: context.isMobile ? 40 : 25),

                      _buildActionButtonsSection(context),

                      // Increased spacing here
                      SizedBox(height: context.isMobile ? 150 : 45),

                      _buildAboutSection(context),

                      const Spacer(),

                      _buildFooterSection(context),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(
            context.responsive(ResponsiveSize.paddingSmall) + 2,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfacePrimary,
            shape: BoxShape.circle,
            boxShadow: const [AppTheme.cardShadow],
          ),
          child: Icon(
            Icons.school,
            size: context.responsive(ResponsiveSize.iconLarge) - 4,
            color: AppTheme.greenPrimary,
          ),
        ),
        SizedBox(height: context.responsive(ResponsiveSize.paddingSmall)),
        Text(
          'EduAssist',
          style: AppTheme.headingMedium.copyWith(
            color: Colors.white,
            fontSize: context.responsive(ResponsiveSize.headingMedium) - 2,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.responsive(ResponsiveSize.paddingSmall) / 2),
        Text(
          'Empowering Education Through Technology',
          style: AppTheme.bodyMedium.copyWith(
            color: Colors.white70,
            fontSize: context.responsive(ResponsiveSize.bodyMedium),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtonsSection(BuildContext context) {
    return ResponsiveRow(
      spacing: 12,
      children: [
        _buildActionButton(
          context,
          title: 'Get Started',
          subtitle: 'Choose your school and sign in',
          icon: Icons.rocket_launch,
          onPressed: () => context.go(AppConstants.schoolSelectionRoute),
          isPrimary: true,
        ),
        _buildActionButton(
          context,
          title: 'Manage Schools',
          subtitle: 'Add and manage educational institutions',
          icon: Icons.admin_panel_settings,
          onPressed: () => _showLoginDialog(context),
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.responsive(ResponsiveSize.paddingSmall),
      ),
      decoration: AppTheme.getGlassDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: AppTheme.borderRadius12,
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      padding: EdgeInsets.all(context.isMobile ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: AppTheme.borderRadius8,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: context.isMobile ? 16 : 14,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'About EduAssist',
                style: AppTheme.labelMedium.copyWith(
                  color: Colors.white,
                  fontSize: context.isMobile ? 14 : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: context.isMobile ? 12 : 10),

          Text(
            'EduAssist is a comprehensive school management platform designed to streamline educational administration and enhance communication between schools, teachers, students, and parents.',
            style: AppTheme.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: context.isMobile ? 12 : 11,
              height: 1.4,
            ),
          ),

          SizedBox(height: context.isMobile ? 12 : 8),

          // Feature highlights
          ...[
            _buildFeatureItem(
              context,
              Icons.assignment,
              'Assignment & Grade Management',
            ),
            _buildFeatureItem(
              context,
              Icons.notifications_active,
              'Real-time Notifications & Communication',
            ),
            _buildFeatureItem(
              context,
              Icons.analytics,
              'Comprehensive Analytics & Reports',
            ),
            _buildFeatureItem(
              context,
              Icons.people,
              'Multi-role Access (Students, Teachers, Admins)',
            ),
          ],

          SizedBox(height: context.isMobile ? 10 : 6),

          Container(
            padding: EdgeInsets.all(context.isMobile ? 10 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: AppTheme.borderRadius8,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: Colors.white.withOpacity(0.8),
                  size: context.isMobile ? 14 : 12,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Secure, scalable, and designed for modern educational institutions',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: context.isMobile ? 11 : 10,
                      fontStyle: FontStyle.italic,
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

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.isMobile ? 6 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.7),
              size: context.isMobile ? 14 : 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.8),
                fontSize: context.isMobile ? 11 : 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Container(
      decoration: AppTheme.getGlassDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppTheme.borderRadius12,
          child: Padding(
            padding: EdgeInsets.all(
              context.responsive(ResponsiveSize.paddingSmall) + 2,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    context.responsive(ResponsiveSize.paddingSmall) - 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: isPrimary
                        ? AppTheme.primaryGradient
                        : AppTheme.primaryGradientHover,
                    borderRadius: AppTheme.borderRadius8,
                    boxShadow: const [AppTheme.cardShadow],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: context.responsive(ResponsiveSize.iconSmall) + 2,
                  ),
                ),
                SizedBox(
                  width: context.responsive(ResponsiveSize.paddingSmall) + 2,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.labelMedium.copyWith(
                          fontSize: context.responsive(
                            ResponsiveSize.bodyMedium,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height:
                            context.responsive(ResponsiveSize.paddingSmall) / 3,
                      ),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.neutral600,
                          fontSize: context.responsive(
                            ResponsiveSize.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(
                    context.responsive(ResponsiveSize.paddingSmall) - 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.green50,
                    borderRadius: AppTheme.borderRadius8,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.greenPrimary,
                    size: context.responsive(ResponsiveSize.iconSmall) - 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterSection(BuildContext context) {
    return Text(
      'Powering the Future of Education',
      style: AppTheme.bodySmall.copyWith(
        color: Colors.white60,
        fontSize: context.responsive(ResponsiveSize.bodySmall) - 1,
      ),
      textAlign: TextAlign.center,
    );
  }

  // "Manage Schools" opens the login card directly (phone/email + password) —
  // no intermediate "Admin Access" card. Super-admin logs in here.
  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: LoginCard(
            roleLabel: 'Admin',
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

}
