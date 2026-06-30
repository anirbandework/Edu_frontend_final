import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart';
import 'core/utils/app_router.dart';
import 'features/ai/services/ai_assistant_manager.dart';
import 'core/auth/auth_session.dart';
import 'core/auth/permission_store.dart';
import 'features/auth/services/auth_api_service.dart';
import 'features/ai/widgets/ai_assistant_widget.dart';

// NEW: global scaffold messenger key
import 'shared/root_scaffold_messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Refuse to launch a RELEASE build that's still pointed at a dev host (no-op in
  // debug/profile). The real URL comes from --dart-define=API_BASE_URL=... in CI.
  AppConstants.assertApiBaseUrlConfigured();
  // Rehydrate the saved session BEFORE the router builds, so a web refresh /
  // relaunch keeps the user logged in instead of bouncing to /login.
  await AuthSession.instance.restore();
  if (AuthSession.instance.isAuthenticated) {
    if (AuthSession.instance.accessTokenExpired) {
      await AuthApiService.refreshSession(); // mint a fresh token (or clear if invalid)
    }
    if (AuthSession.instance.isAuthenticated) {
      // Preload permissions, but never let a slow/down server block or crash
      // launch — the sidebar reacts to PermissionStore once it loads.
      try {
        await PermissionStore.instance.load();
      } catch (_) {}
    }
  }
  runApp(const ProviderScope(child: EduAssistApp()));
}

class EduAssistApp extends ConsumerStatefulWidget {
  const EduAssistApp({super.key});

  @override
  ConsumerState<EduAssistApp> createState() => _EduAssistAppState();
}

class _EduAssistAppState extends ConsumerState<EduAssistApp> {
  @override
  void initState() {
    super.initState();
    // Initialize the AI assistant after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AIAssistantManager.initialize(ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EduAssist - Educational Management Platform',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,

      // CRITICAL: make a ScaffoldMessenger always available globally
      scaffoldMessengerKey: rootScaffoldMessengerKey,

      // Wrap router output with a top-level Scaffold so SnackBars
      // always have a visible surface even if a route tree lacks one.
      builder: (context, child) {
        // Respect the OS font-size accessibility setting, but CLAMP it to a safe
        // range so extreme settings don't break layouts (was hard-pinned to 1.0,
        // which ignored accessibility entirely).
        final mq = MediaQuery.of(context);
        final media = mq.copyWith(
          textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
        );

        final stacked = Stack(
          children: [
            child ?? const SizedBox.shrink(),
            // AI Assistant overlay remains on top of all pages
            Consumer(
              builder: (context, ref, _) {
                final assistantState = ref.watch(aiAssistantProvider);
                return assistantState.isVisible
                    ? const AIAssistantWidget()
                    : const SizedBox.shrink();
              },
            ),
          ],
        );

        // If your routed pages already provide their own Scaffold,
        // this outer Scaffold will primarily serve as the SnackBar host.
        return MediaQuery(
          data: media,
          child: Scaffold(
            body: stacked,
          ),
        );
      },
    );
  }
}
