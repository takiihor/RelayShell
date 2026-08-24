import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/platform/secure_window.dart';
import '../features/settings/app_lock_screen.dart';
import '../features/terminal/terminal_providers.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Navigator key shared with the core layer.
///
/// Host-key trust and passphrase prompts originate deep inside the SSH stack,
/// which has no `BuildContext`. Routing them through one known navigator is the
/// smallest seam that keeps those decisions in the user's hands without the
/// core depending on Flutter's widget tree.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// The application root.
class RelayShellApp extends ConsumerStatefulWidget {
  const RelayShellApp({super.key});

  @override
  ConsumerState<RelayShellApp> createState() => _RelayShellAppState();
}

class _RelayShellAppState extends ConsumerState<RelayShellApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = createRouter(navigatorKey: rootNavigatorKey);

  static const SecureWindow _secureWindow = SecureWindow();
  bool _windowSecured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Marks the window secure while app lock is enabled, so terminal output does
  /// not appear in the OS app-switcher thumbnail (SPEC 19).
  Future<void> _syncWindowSecurity(bool shouldSecure) async {
    if (shouldSecure == _windowSecured) return;
    _windowSecured = shouldSecure;
    await _secureWindow.setSecure(secure: shouldSecure);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  /// Lifecycle handling (SPEC 28).
  ///
  /// Sockets can vanish while backgrounded without the transport noticing, so
  /// returning to the foreground re-checks every connection rather than
  /// trusting a stale "connected" flag.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appLock = ref.read(appLockProvider);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        appLock.onBackgrounded();
      case AppLifecycleState.resumed:
        appLock.onForegrounded();
        ref.read(terminalManagerProvider).reviewAfterForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(preferencesProvider);
    final appLock = ref.watch(appLockProvider);

    unawaited(_syncWindowSecurity(preferences.appLockEnabled));

    return MaterialApp.router(
      title: 'Remote Dev Console',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: AppTheme.themeModeFrom(preferences.themeMode),
      theme: AppTheme.light().copyWith(
        extensions: [StatusColors.of(Brightness.light)],
      ),
      darkTheme: AppTheme.dark().copyWith(
        extensions: [StatusColors.of(Brightness.dark)],
      ),
      locale: preferences.locale == null ? null : Locale(preferences.locale!),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        // The lock is drawn above the whole app rather than routed to, so a
        // deep link or a resumed route cannot land behind it.
        return Stack(
          children: [
            ?child,
            if (appLock.isLocked) const AppLockScreen(),
          ],
        );
      },
    );
  }
}
