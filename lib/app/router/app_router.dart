import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/commands/command_edit_screen.dart';
import '../../features/commands/commands_screen.dart';
import '../../features/conversation_shell/conversation_shell_screen.dart';
import '../../features/forwarding/forwarding_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/hosts/host_edit_screen.dart';
import '../../features/keys/keys_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/trusted_keys_screen.dart';
import '../../features/terminal/terminal_screen.dart';
import '../../shared/navigation/routes.dart';

/// The application router.
///
/// Conversation-first application routing.
///
/// A remote development session starts from a computer and immediately opens
/// Conversation Shell. Projects and saved sessions are deliberately not part
/// of the product navigation: they remain in the local database for backwards
/// compatibility, but do not compete with the work surface.
GoRouter createRouter({GlobalKey<NavigatorState>? navigatorKey}) {
  final rootKey = navigatorKey ?? GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.hostNew,
        builder: (context, state) => const HostEditScreen(),
      ),
      GoRoute(
        path: '/computers/:hostId/edit',
        builder: (context, state) =>
            HostEditScreen(hostId: state.pathParameters['hostId']),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'trusted-keys',
            builder: (context, state) => const TrustedKeysScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.keys,
        builder: (context, state) => const KeysScreen(),
      ),
      GoRoute(
        path: Routes.forwarding,
        builder: (context, state) => const ForwardingScreen(),
      ),
      GoRoute(
        path: Routes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: Routes.commands,
        builder: (context, state) => const CommandsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => CommandEditScreen(
              initialHostId: state.uri.queryParameters['host'],
            ),
          ),
          GoRoute(
            path: ':commandId',
            builder: (context, state) =>
                CommandEditScreen(commandId: state.pathParameters['commandId']),
          ),
        ],
      ),

      // Full-screen work surfaces stay separate from connection setup.
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.conversation,
        builder: (context, state) => ConversationShellScreen(
          sessionId: state.uri.queryParameters['session'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.terminal,
        builder: (context, state) =>
            TerminalScreen(sessionId: state.uri.queryParameters['session']),
      ),
    ],
  );
}
