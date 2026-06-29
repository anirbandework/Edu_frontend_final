// lib/features/screens/landing_screen.dart
//
// Standalone pre-login landing page (loads at "/"). Green + white design system:
// a green gradient backdrop, white rounded action cards (each with one green
// accent), and a translucent "About" panel. Fully responsive — two columns on
// web, single column on phones — and vertically centred so it never looks
// top/left-stuck. No 3D, no animations (just Material tap feedback).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/auth/auth_session.dart';
import '../../shared/widgets/login_card.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const double _bp = 760; // wide / mobile breakpoint

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= _bp;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Stack(
          children: [
            // Subtle static light from the top for depth (no animation).
            const Positioned.fill(child: _TopGlow()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 32 : 20,
                            vertical: 28,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 940),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _header(isWide),
                                SizedBox(height: isWide ? 44 : 36),
                                _actions(context, isWide),
                                SizedBox(height: isWide ? 28 : 22),
                                _about(isWide),
                                const SizedBox(height: 24),
                                _footer(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _header(bool isWide) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.apartment, size: 42, color: AppTheme.greenPrimary),
        ),
        const SizedBox(height: 18),
        Text(
          'EduAssist',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.bauhausFontFamily,
            fontSize: isWide ? 40 : 30,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Empowering education through technology',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.interFontFamily,
            fontSize: isWide ? 17 : 15,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }

  // ── Primary actions ───────────────────────────────────────────────────────
  Widget _actions(BuildContext context, bool isWide) {
    final getStarted = _ActionCard(
      title: 'Get Started',
      subtitle: 'Choose your organisation and sign in',
      icon: Icons.rocket_launch_outlined,
      onTap: () => context.go(AppConstants.organisationSelectionRoute),
    );
    final manage = _ActionCard(
      title: 'Manage Organisations',
      subtitle: 'Add and manage educational institutions',
      icon: Icons.admin_panel_settings_outlined,
      onTap: () => _showLoginDialog(context),
    );

    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: getStarted),
            const SizedBox(width: 16),
            Expanded(child: manage),
          ],
        ),
      );
    }
    return Column(
      children: [getStarted, const SizedBox(height: 14), manage],
    );
  }

  // ── About panel ─────────────────────────────────────────────────────────
  Widget _about(bool isWide) {
    const desc =
        'EduAssist is a comprehensive organisation management platform that streamlines '
        'administration and strengthens communication between organisations, teachers, '
        'students and parents.';

    final description = Text(
      desc,
      style: TextStyle(
        fontFamily: AppTheme.interFontFamily,
        fontSize: 14.5,
        height: 1.6,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );

    const features = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Feature(Icons.assignment_outlined, 'Assignment & grade management'),
        _Feature(Icons.notifications_active_outlined,
            'Real-time notifications & communication'),
        _Feature(Icons.insights_outlined, 'Comprehensive analytics & reports'),
        _Feature(Icons.groups_2_outlined,
            'Multi-role access — students, teachers, admins'),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isWide ? 26 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: AppTheme.borderRadius8,
                ),
                child:
                    const Icon(Icons.info_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'About EduAssist',
                style: TextStyle(
                  fontFamily: AppTheme.bauhausFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isWide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: description),
                  const SizedBox(width: 28),
                  const Expanded(child: features),
                ],
              ),
            )
          else ...[
            description,
            const SizedBox(height: 18),
            features,
          ],
          const SizedBox(height: 18),
          _secureNote(),
        ],
      ),
    );
  }

  Widget _secureNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: AppTheme.borderRadius12,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Secure, scalable and designed for modern educational institutions.',
              style: TextStyle(
                fontFamily: AppTheme.interFontFamily,
                fontSize: 13.5,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Text(
      'EduAssist · Powering the future of education',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.interFontFamily,
        fontSize: 12.5,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }

  // "Manage Organisations" opens the login card directly (phone + password). The
  // forgot-password flow runs inside that same card (no separate page).
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

// ── White action card (hover-aware on web; tap ripple on all) ────────────────
class _ActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: _hover ? 8 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.borderRadius12,
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 25),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: AppTheme.bauhausFontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.neutral900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontFamily: AppTheme.interFontFamily,
                          fontSize: 13.5,
                          height: 1.35,
                          color: AppTheme.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.greenPrimary
                        .withValues(alpha: _hover ? 0.16 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: AppTheme.greenPrimary, size: 19),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feature row (white-on-green) ────────────────────────────────────────────
class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: AppTheme.borderRadius8,
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: AppTheme.interFontFamily,
                  fontSize: 14,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Static top light glow (depth, no animation) ──────────────────────────────
class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.1),
            radius: 1.1,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
