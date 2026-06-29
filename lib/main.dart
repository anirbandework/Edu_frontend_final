import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/utils/app_router.dart';
import 'core/services/ai_assistant_manager.dart';
import 'shared/widgets/ai_assistant_widget.dart';

// NEW: global scaffold messenger key
import 'shared/root_scaffold_messenger.dart';

void main() {
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
        final media = MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0));

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
