// lib/shared/widgets/sa_widgets.dart
//
// Phone-first design system for the SUPER-ADMIN surface (Organisations, Admins,
// Module Access, Analytics, Feedback, Profile). The global AppTheme type scale
// is deliberately desktop-sized ("Was 24 -> 32"), which crowds a phone; these
// tokens + building blocks give the section a calmer, compact, consistent look:
//   • white cards with ONE green accent (not a flood of coloured pills)
//   • compact typography and enforced 48px touch targets
//   • shared loading / empty / error states (error keeps a "Try again")
//   • a gradient page header that doubles as a hero (avatar) when needed
//
// The MainLayout shell already supplies the top bar, SafeArea, background and an
// 8px content inset, so these widgets never add a Scaffold/AppBar of their own.
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';

/// Compact, phone-first design tokens for the super-admin surface.
class Sa {
  Sa._();

  // Spacing scale.
  static const double gapXs = 6;
  static const double gap = 12;
  static const double gapLg = 16;
  static const double pagePad = 16;
  static const double radius = 18;

  // Colours (reuse the brand; one accent per card).
  static const Color accent = AppTheme.greenPrimary;
  static const Color stroke = AppTheme.neutral200;
  static const Color surface = Colors.white;

  // Compact typography. Bauhaus for chrome/titles, Inter for prose.
  static const TextStyle headerTitle = TextStyle(
    fontFamily: AppTheme.bauhausFontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.2,
  );
  static const TextStyle headerSubtitle = TextStyle(
    fontFamily: AppTheme.interFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: Colors.white70,
    height: 1.3,
  );
  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppTheme.bauhausFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppTheme.neutral900,
    height: 1.25,
  );
  static const TextStyle label = TextStyle(
    fontFamily: AppTheme.interFontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppTheme.neutral500,
    height: 1.3,
  );
  static const TextStyle value = TextStyle(
    fontFamily: AppTheme.interFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTheme.neutral800,
    height: 1.35,
  );
  static const TextStyle body = TextStyle(
    fontFamily: AppTheme.interFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppTheme.neutral600,
    height: 1.45,
  );

  /// Soft card shadow shared by every super-admin card.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(16, 24, 40, 0.06),
      offset: Offset(0, 4),
      blurRadius: 14,
      spreadRadius: -4,
    ),
  ];
}

/// Page layout for a super-admin screen: a [header] pinned to the top and a
/// fill-remaining [child] that scrolls itself. Never wraps a Scaffold/AppBar —
/// the shell owns those.
///
/// There is deliberately NO bottom-right FAB slot. The global AI assistant
/// floating button (see `lib/shared/widgets/ai_assistant_widget.dart`) lives in
/// the bottom-right corner of every page, so a page-level button there would
/// collide with it. Put a page's primary action in the header instead — use
/// [SaGradientHeader.trailing] with a [SaHeaderAction].
class SaScreen extends StatelessWidget {
  final Widget header;
  final Widget child;
  const SaScreen({
    super.key,
    required this.header,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, Expanded(child: child)],
    );
  }
}

/// Gradient page header. By default shows an icon tile + title + subtitle; pass
/// [leading] to swap the tile for a hero element (e.g. an avatar) and
/// [trailing] for an optional end widget. Rounds all corners so it reads as a
/// hero card within the shell's 8px inset.
class SaGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  const SaGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.dashboard_customize_outlined,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(Sa.radius),
        boxShadow: const [AppTheme.greenShadow],
      ),
      child: Row(
        children: [
          leading ??
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppTheme.borderRadius12,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Sa.headerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: Sa.headerSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Sa.gapXs), trailing!],
        ],
      ),
    );
  }
}

/// A compact icon action for the [SaGradientHeader.trailing] slot: a translucent
/// white tile on the green header with a ≥44px touch target. Use this for a
/// page's primary action (e.g. "Add", "New") INSTEAD of a bottom-right FAB —
/// that corner is reserved for the global AI assistant. Pass [onPressed] = null
/// to render a disabled (dimmed) state; multiple actions can sit in a [Row].
class SaHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  const SaHeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppTheme.borderRadius12,
        child: Container(
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.07),
            borderRadius: AppTheme.borderRadius12,
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: enabled ? 1 : 0.5),
            size: 22,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// White rounded card with a soft shadow — the standard super-admin container.
class SaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const SaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: Sa.surface,
      borderRadius: BorderRadius.circular(Sa.radius),
      border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
      boxShadow: Sa.cardShadow,
    );
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }
    return Material(
      color: Sa.surface,
      borderRadius: BorderRadius.circular(Sa.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Sa.radius),
        child: Ink(
          padding: padding,
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}

/// A card's heading row: a tinted accent icon, a title and an optional trailing.
class SaCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? color;
  const SaCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Sa.accent;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: AppTheme.borderRadius8,
          ),
          child: Icon(icon, size: 17, color: c),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: Sa.cardTitle)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A label/value detail row that wraps its value gracefully on narrow phones.
class SaInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const SaInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label, style: Sa.label)),
          const SizedBox(width: Sa.gap),
          Expanded(child: Text(value, style: Sa.value)),
        ],
      ),
    );
  }
}

/// A single, subtle status pill (replaces the multi-colour pill soup).
class SaStatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const SaStatusPill({
    super.key,
    required this.text,
    this.color = AppTheme.greenPrimary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppTheme.borderRadius8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.interFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A filled green CTA with an enforced 48px touch target and busy state.
class SaPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool expand;
  final Color color;
  const SaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.color = Sa.accent,
  });

  @override
  Widget build(BuildContext context) {
    final Widget leading = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Icon(icon ?? Icons.check, size: 18);
    final button = ElevatedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: leading,
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius12),
        textStyle: const TextStyle(
          fontFamily: AppTheme.bauhausFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Full-height, centred loading indicator.
class SaLoading extends StatelessWidget {
  final String? message;
  const SaLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Sa.accent, strokeWidth: 3),
          if (message != null) ...[
            const SizedBox(height: Sa.gap),
            Text(message!, style: Sa.body),
          ],
        ],
      ),
    );
  }
}

/// Full-height state view for EMPTY and ERROR. When [onRetry] is provided a
/// "Try again" recovery button is shown (used for error states only).
class SaStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Widget? action;
  const SaStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor = AppTheme.neutral400,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.action,
  });

  /// Error variant: red icon + a "Try again" button wired to [onRetry].
  factory SaStateView.error({
    required String message,
    required VoidCallback onRetry,
  }) =>
      SaStateView(
        icon: Icons.error_outline_rounded,
        iconColor: AppTheme.error,
        title: 'Something went wrong',
        subtitle: message,
        onRetry: onRetry,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: Sa.gapLg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Sa.cardTitle.copyWith(fontSize: 16),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: Sa.body),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: Sa.gapLg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: Text(retryLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Sa.accent,
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: Sa.accent, width: 1.5),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadius12),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Sa.gapLg), action!],
          ],
        ),
      ),
    );
  }
}
