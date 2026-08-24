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
import '../shell/app_shell.dart';

/// Route paths, in one place so links cannot drift apart from the router.
class Routes {
  const Routes._();

  static const String home = '/';
  static const String hosts = '/computers';
  static const String hostNew = '/computers/new';
  static String hostDetail(String id) => '/computers/$id';
  static String hostEdit(String id) => '/computers/$id/edit';

  static const String projects = '/projects';
  static const String projectNew = '/projects/new';
  static String projectDetail(String id) => '/projects/$id';
  static String projectEdit(String id) => '/projects/$id/edit';

  static const String sessions = '/sessions';
  static const String more = '/more';

  static const String commands = '/more/commands';
  static const String commandNew = '/more/commands/new';
  static String commandEdit(String id) => '/more/commands/$id';

  static const String keys = '/more/keys';
  static const String forwarding = '/more/forwarding';
  static const String settings = '/more/settings';
  static const String trustedKeys = '/more/settings/trusted-keys';
  static const String about = '/more/about';

  static const String search = '/search';
  static const String terminal = '/terminal';

  static String files(String hostId) => '/files/$hostId';
}

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
        builder: (context, state) => TerminalScreen(
          sessionId: state.uri.queryParameters['session'],
        ),
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
