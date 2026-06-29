# EduAssist — Phone-First UI Design System

> **Read this before designing ANY page.** Follow it and the page will match the rest of the app
> with no guesswork. Proven on all 6 super-admin pages (Profile, Analytics, Feedback, Module
> Access, Admins, Tenants).

**Design language in one line:** phone-first, **green + white** with neutral gray, white rounded
cards with a single green accent, compact type, generous touch targets, no clutter.

The reusable building blocks live in
[`lib/features/super_admin/widgets/sa_widgets.dart`](../lib/features/super_admin/widgets/sa_widgets.dart).
Always compose these instead of hand-rolling containers/headers/buttons — that's what keeps every
page consistent.

---

## 1. The golden rules (do not break these)

1. **No `Scaffold`, no `AppBar` in a screen.** The `MainLayout` shell already provides the top bar
   (with the hamburger), `SafeArea`, the background, and an 8px content inset, and it puts your
   screen inside a fill-remaining scroll area. Your `build()` returns a widget that **fills the
   remaining space and scrolls itself** — use `SaScreen`. (Adding your own AppBar = a double header.)
2. **Phone-first type = `Sa.*` tokens, not `AppTheme.headingX/bodyX`.** The global `AppTheme` text
   scale is desktop-sized (e.g. body is 16–18px, headings 24–32px) and crowds a phone. Use the
   compact `Sa.cardTitle / Sa.value / Sa.label / Sa.body` instead.
3. **Palette = green + white + neutral gray.** Green for anything positive/active/primary, neutral
   gray for muted/secondary, **red only for errors / destructive / validation**. No blue, cyan,
   amber, teal, purple. The only gradient is the green `AppTheme.primaryGradient`.
4. **No manual refresh.** No "Refresh" buttons, no pull-to-refresh (`RefreshIndicator`). Pages load
   fresh on open. On a failed load, show `SaStateView.error(onRetry: _load)` ("Try again" appears
   only on failure).
5. **Touch targets ≥ 44–48px.** Use `SaPrimaryButton` (48px), or set `minimumSize`/`constraints`.
6. **Nothing wider than the screen.** No fixed pixel widths bigger than ~360px. Dialogs are
   constrained / near-full-screen / bottom sheets. Collapse multi-column rows to one column on phones.
7. **Nothing in the bottom-right corner — the AI assistant lives there.** A global AI assistant
   floating button ([`lib/shared/widgets/ai_assistant_widget.dart`](../lib/shared/widgets/ai_assistant_widget.dart))
   overlays **every** page at the bottom-right (and its chat window opens just above it). **Never**
   place a `FloatingActionButton`, a `Positioned`/`Align` button, or any other tappable control in
   that corner — it will collide with the assistant. Put a page's primary action (Add / New / Create)
   in the **header** instead: `SaGradientHeader(trailing: SaHeaderAction(...))`. `SaScreen`
   deliberately has **no `fab` slot**, and the `MainLayout` shell adds no bottom-right button (the
   sidebar is opened from the header hamburger).

---

## 2. What to use from `AppTheme` vs `Sa`

`AppTheme` ([`lib/core/constants/app_theme.dart`](../lib/core/constants/app_theme.dart)) — use it for:

| Use from AppTheme | Examples |
|---|---|
| **Colors** | `greenPrimary` (#2E7D32 brand), `neutral50..neutral900` (gray ramp), `error` (red), `green50` (tint) |
| **Gradient** | `primaryGradient` (green→green) — the ONLY gradient |
| **Radii** | `borderRadius8`, `borderRadius12`, `borderRadius16` |
| **Shadow** | `greenShadow` (for the gradient header) |

**Do NOT use** `AppTheme.headingLarge/Medium/Small`, `bodyLarge/Medium/Small` for phone screens
(desktop-sized). Do NOT use `AppTheme.success` / `info` / `warning` (off-brand teal/blue/amber) —
they were removed everywhere; use green or neutral.

`Sa` (in `sa_widgets.dart`) — the phone-first tokens:

```dart
Sa.gapXs   // 6     small spacing
Sa.gap     // 12    default spacing between elements
Sa.gapLg   // 16    spacing between cards
Sa.pagePad // 16    page horizontal padding
Sa.radius  // 18    card / header / dialog corner radius
Sa.accent  // = AppTheme.greenPrimary  (the one accent)
Sa.stroke  // = AppTheme.neutral200    (hairline borders)
Sa.surface // = Colors.white

// Compact text styles (use these on phone)
Sa.headerTitle    // 19 / w700 / white   — gradient header title
Sa.headerSubtitle // 13 / white70        — gradient header subtitle
Sa.cardTitle      // 15 / w700 / neutral900
Sa.value          // 14 / w600 / neutral800   — primary value text
Sa.label          // 12.5 / w500 / neutral500 — muted label text
Sa.body           // 14 / w400 / neutral600   — paragraph text
Sa.cardShadow     // soft card shadow
```

---

## 3. Component reference (`sa_widgets.dart`)

```dart
// Page layout — header pinned top, child fills & scrolls.
// NO `fab` slot: the bottom-right corner is reserved for the AI assistant (rule 7).
SaScreen({ required Widget header, required Widget child })

// Green gradient hero header. `leading` overrides the icon tile (e.g. avatar).
// Put a page's primary action in `trailing` (a SaHeaderAction).
SaGradientHeader({ required String title, String? subtitle,
                   IconData icon, Widget? leading, Widget? trailing,
                   EdgeInsetsGeometry padding })

// A page's primary action for the header's `trailing` slot: a translucent white
// tile on the green header, ≥44px touch target. Use this INSTEAD of a bottom-right
// FAB. `onPressed: null` renders a dimmed/disabled state. Two actions? put them in
// a Row(mainAxisSize: MainAxisSize.min, ...).
SaHeaderAction({ required IconData icon, required VoidCallback? onPressed, String? tooltip })

// White rounded card + soft shadow. `onTap` makes the whole card tappable.
SaCard({ required Widget child, EdgeInsetsGeometry padding = EdgeInsets.all(16),
         VoidCallback? onTap })

// A card's heading row: tinted accent icon tile + title + optional trailing.
SaCardHeader({ required IconData icon, required String title,
               Widget? trailing, Color? color })

// Label / value detail row (value wraps).
SaInfoRow({ required String label, required String value })

// One subtle status pill (defaults to green).
SaStatusPill({ required String text, Color color = AppTheme.greenPrimary, IconData? icon })

// Filled green CTA, 48px tall, with busy spinner. `expand:true` = full width.
SaPrimaryButton({ required String label, required VoidCallback? onPressed,
                  IconData? icon, bool busy = false, bool expand = false,
                  Color color = Sa.accent })

// Full-height centred spinner.
SaLoading({ String? message })

// Full-height empty/error state. `.error()` adds a "Try again" button.
SaStateView({ required IconData icon, required String title, String? subtitle,
              Color iconColor = AppTheme.neutral400, VoidCallback? onRetry,
              String retryLabel = 'Try again', Widget? action })
SaStateView.error({ required String message, required VoidCallback onRetry })
```

---

## 4. Build a new page — copy this skeleton

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../widgets/sa_widgets.dart';            // adjust relative path
import '../../../services/your_service.dart';

class ThingScreen extends StatefulWidget {
  const ThingScreen({super.key});
  @override
  State<ThingScreen> createState() => _ThingScreenState();
}

class _ThingScreenState extends State<ThingScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await YourService.getThings();
      if (!mounted) return;
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Things',
          subtitle: 'Everything in one place',
          icon: Icons.category_outlined,
          // Primary "Create" action goes in the header — NOT a bottom-right FAB
          // (the AI assistant owns that corner; see rule 7).
          trailing: SaHeaderAction(
            icon: Icons.add,
            tooltip: 'Add thing',
            onPressed: _create,
          ),
        ),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const SaLoading(message: 'Loading…');
    if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return const SaStateView(
        icon: Icons.inbox_outlined, title: 'Nothing yet',
        subtitle: 'Items will appear here once created.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (_, i) => _card(_items[i]),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(
            icon: Icons.label_outline,
            title: (item['name'] ?? '').toString(),
            trailing: SaStatusPill(
              text: item['active'] == true ? 'Active' : 'Inactive',
              color: item['active'] == true ? AppTheme.greenPrimary : AppTheme.neutral400,
            ),
          ),
          const SizedBox(height: Sa.gap),
          SaInfoRow(label: 'Owner', value: (item['owner'] ?? '—').toString()),
        ],
      ),
    );
  }
}
```

Key rules baked into the skeleton: header `Padding(8,4,8,0)`, body padding `(8,12,8,28)` so the
header and cards line up; loading/error/empty all go through the `Sa*` state widgets.

---

## 5. Pattern library

**Buttons** — full-width form submit:
```dart
SaPrimaryButton(
  label: _saving ? 'Saving…' : 'Save',
  icon: Icons.check_rounded, busy: _saving, expand: true,
  onPressed: _submit);
```

**Page primary action (header, NOT a bottom-right FAB)** — Add / New / Create lives in the header:
```dart
SaGradientHeader(
  title: 'My Quizzes', icon: Icons.quiz_outlined,
  trailing: SaHeaderAction(
    icon: Icons.add, tooltip: 'New quiz', onPressed: _newQuiz));   // onPressed: null = disabled

// Two actions (e.g. import + add)? Wrap them in a Row:
trailing: Row(mainAxisSize: MainAxisSize.min, children: [
  SaHeaderAction(icon: Icons.upload_file, tooltip: 'Bulk import', onPressed: _import),
  const SizedBox(width: Sa.gapXs),
  SaHeaderAction(icon: Icons.add, tooltip: 'Add student', onPressed: _add),
]);
```

**Inline KPI / stat card** (green accent tile):
```dart
SaCard(child: Row(children: [
  Container(width: 38, height: 38,
    decoration: BoxDecoration(color: Sa.accent.withOpacity(0.12),
      borderRadius: AppTheme.borderRadius12),
    child: const Icon(Icons.school, color: Sa.accent, size: 22)),
  const Spacer(),
  Text('1,240', style: AppTheme.headingMedium.copyWith(
    color: AppTheme.neutral900, fontWeight: FontWeight.w800)),
]));
```

**Wrap badges so they never overflow** (don't put pills in a fixed `Row`):
```dart
Wrap(spacing: 8, runSpacing: 8, children: [
  SaStatusPill(text: 'Active', color: AppTheme.greenPrimary, icon: Icons.check_circle_outline),
  _statBadge('120', Icons.people),   // all accents green
]);
```

**Progress bar** (green fill, neutral track):
```dart
ClipRRect(borderRadius: AppTheme.borderRadius8,
  child: LinearProgressIndicator(value: pct, minHeight: 10,
    backgroundColor: AppTheme.neutral200,
    valueColor: const AlwaysStoppedAnimation(AppTheme.greenPrimary)));
```

**Selectable chip with guaranteed contrast** (white label on dark green):
```dart
FilterChip(
  label: const Text('Grade 5'),
  selected: isSelected,
  selectedColor: AppTheme.greenPrimary,
  checkmarkColor: Colors.white,
  labelStyle: TextStyle(
    color: isSelected ? Colors.white : AppTheme.neutral700,
    fontWeight: FontWeight.w500),
  onSelected: (v) {/* ... */});
```

**Filter / sort that doesn't fit → a bottom sheet** (instead of cramming a toolbar):
```dart
showModalBottomSheet<void>(
  context: context, backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SafeArea(
    child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sort & options', style: Sa.cardTitle),
          // SwitchListTile(activeColor: Sa.accent, ...), ListTile(...),
        ])))));
```

**Responsive dialog** (never wider than the screen):
```dart
final maxW = MediaQuery.of(context).size.width - 24;
Dialog(
  insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
  backgroundColor: Sa.surface,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxW > 520 ? 520 : maxW,
      maxHeight: MediaQuery.of(context).size.height - 80),
    child: Column(mainAxisSize: MainAxisSize.min, children: [/* ... */])));
```

**Collapse multi-column form rows on phones:**
```dart
LayoutBuilder(builder: (context, c) {
  final oneCol = c.maxWidth < 600;
  return oneCol
    ? Column(children: [field1, const SizedBox(height: Sa.gap), field2])
    : Row(children: [Expanded(child: field1), const SizedBox(width: Sa.gap),
                     Expanded(child: field2)]);
});
```

**Snackbar** (success = green, error = red):
```dart
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text(msg),
  backgroundColor: ok ? AppTheme.greenPrimary : AppTheme.error,
  behavior: SnackBarBehavior.floating));
```

**Destructive / kebab menu icons** — green for view/activate, neutral for edit/deactivate, red for delete:
```dart
PopupMenuItem(value: 'edit', child: Row(children: const [
  Icon(Icons.edit, size: 18, color: AppTheme.neutral600), SizedBox(width: 10), Text('Edit')])),
PopupMenuItem(value: 'delete', child: Row(children: const [
  Icon(Icons.delete_outline, size: 18, color: AppTheme.error), SizedBox(width: 10),
  Text('Delete', style: TextStyle(color: AppTheme.error))])),
```

---

## 6. States — always handle all three

```dart
if (_loading)   return const SaLoading(message: 'Loading…');
if (_error != null) return SaStateView.error(message: _error!, onRetry: _load);
if (_items.isEmpty) return const SaStateView(icon: Icons.inbox_outlined, title: 'Nothing yet');
return _list();   // happy path
```

Inside a dialog, wrap the state in vertical padding so it isn't flush:
`Padding(padding: EdgeInsets.symmetric(vertical: 24), child: SaStateView.error(...))`.

---

## 7. Pre-flight checklist (before calling a page "done")

- [ ] No `Scaffold` / `AppBar` added (shell provides them).
- [ ] **No bottom-right FAB / button** — the AI assistant owns that corner. Primary action is in the header via `SaGradientHeader(trailing: SaHeaderAction(...))`.
- [ ] Uses `SaScreen` + `SaGradientHeader`; cards are `SaCard`.
- [ ] Loading → `SaLoading`, error → `SaStateView.error(onRetry:)`, empty → `SaStateView`.
- [ ] **No Refresh button, no `RefreshIndicator`.** Error "Try again" kept.
- [ ] Colors are green / white / neutral only; **red only** for error/destructive/validation; only the green gradient.
- [ ] No fixed width > ~360px; dialogs constrained / bottom sheets; multi-col rows collapse < 600px.
- [ ] Pill/badge rows are `Wrap`, not `Row`. Long text uses `Expanded`/`Flexible` + `ellipsis`.
- [ ] Tap targets ≥ 44–48px.
- [ ] Text uses `Sa.*` styles (not desktop `AppTheme.headingX/bodyX`).
- [ ] `dart analyze <files>` → **0 errors, 0 warnings** (info-lints like `withOpacity`/`const` are OK).

---

## 8. File map

| File | Role |
|---|---|
| [`lib/features/super_admin/widgets/sa_widgets.dart`](../lib/features/super_admin/widgets/sa_widgets.dart) | **The design system.** All `Sa*` building blocks + `Sa` tokens. Extend here, don't reinvent. |
| [`lib/core/constants/app_theme.dart`](../lib/core/constants/app_theme.dart) | Colors, gradient, radii, shadows, component themes. (Type scale is desktop-sized — use `Sa.*`.) |
| [`lib/shared/widgets/main_layout.dart`](../lib/shared/widgets/main_layout.dart) | The shell: top bar, SafeArea, background, 8px inset, fill-remaining scroll area. |
| Reference implementations | `profile_screen.dart`, `super_admin/screens/{analytics,feedback,module_access,admins}_screen.dart`, `tenant_management/screens/tenant_management_screen.dart` |

> **When the design system is missing something, add a new `Sa*` widget** to `sa_widgets.dart`
> rather than hardcoding it in a page — that keeps every screen consistent.
