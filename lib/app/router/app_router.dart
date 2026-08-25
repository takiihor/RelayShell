import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/commands/command_edit_screen.dart';
import '../../features/commands/commands_screen.dart';
import '../../features/files/files_screen.dart';
import '../../features/forwarding/forwarding_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/hosts/host_detail_screen.dart';
import '../../features/hosts/host_edit_screen.dart';
import '../../features/hosts/hosts_screen.dart';
import '../../features/keys/keys_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/projects/project_edit_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/trusted_keys_screen.dart';
import '../../features/terminal/terminal_screen.dart';
import '../../shared/navigation/routes.dart';
import '../shell/app_shell.dart';

/// The application router.
///
/// A [StatefulShellRoute] keeps one navigator per tab, so switching from a
/// project back to Home and returning lands where the user left off instead of
/// resetting to the tab root.
GoRouter createRouter({GlobalKey<NavigatorState>? navigatorKey}) {
  final rootKey = navigatorKey ?? GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.hosts,
                builder: (context, state) => const HostsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const HostEditScreen(),
                  ),
                  GoRoute(
                    path: ':hostId',
                    builder: (context, state) => HostDetailScreen(
                      hostId: state.pathParameters['hostId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => HostEditScreen(
                          hostId: state.pathParameters['hostId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.projects,
                builder: (context, state) => const ProjectsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => ProjectEditScreen(
                      initialHostId: state.uri.queryParameters['host'],
                    ),
                  ),
                  GoRoute(
                    path: ':projectId',
                    builder: (context, state) => ProjectDetailScreen(
                      projectId: state.pathParameters['projectId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => ProjectEditScreen(
                          projectId: state.pathParameters['projectId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.sessions,
                builder: (context, state) => const SessionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'commands',
                    builder: (context, state) => const CommandsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => CommandEditScreen(
                          initialHostId: state.uri.queryParameters['host'],
                          initialProjectId:
                              state.uri.queryParameters['project'],
                        ),
                      ),
                      GoRoute(
                        path: ':commandId',
                        builder: (context, state) => CommandEditScreen(
                          commandId: state.pathParameters['commandId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'keys',
                    builder: (context, state) => const KeysScreen(),
                  ),
                  GoRoute(
                    path: 'forwarding',
                    builder: (context, state) => const ForwardingScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'trusted-keys',
                        builder: (context, state) => const TrustedKeysScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes that sit above the tab shell. The terminal in
      // particular must be visually separated from app navigation (SPEC 39).
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.terminal,
        builder: (context, state) =>
            TerminalScreen(sessionId: state.uri.queryParameters['session']),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/files/:hostId',
        builder: (context, state) => FilesScreen(
          hostId: state.pathParameters['hostId']!,
          initialPath: state.uri.queryParameters['path'],
          projectId: state.uri.queryParameters['project'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.search,
        builder: (context, state) => const SearchScreen(),
      ),
    ],
  );
}
