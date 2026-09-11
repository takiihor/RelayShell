import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/providers.dart';
import '../sessions/session_launcher.dart';
import 'terminal_manager.dart';

/// The open terminals. A [ChangeNotifierProvider] because tab state is
/// inherently mutable and long-lived, and rebuilding it per change would throw
/// away every scrollback buffer.
final terminalManagerProvider = ChangeNotifierProvider<TerminalManager>((ref) {
  final services = ref.watch(appServicesProvider);
  // No explicit `ref.onDispose`: ChangeNotifierProvider already disposes the
  // notifier it creates, and calling dispose() twice throws.
  return TerminalManager(
    connections: services.connections,
    sessions: services.sessions,
    multiplexer: services.multiplexer,
  );
});

/// Turns products concepts into running terminals (SPEC 12.3, 13, 14).
final sessionLauncherProvider = Provider<SessionLauncher>((ref) {
  final services = ref.watch(appServicesProvider);
  return SessionLauncher(
    terminals: ref.watch(terminalManagerProvider),
    connections: services.connections,
    hosts: services.hosts,
    projects: services.projects,
    commands: services.commands,
    sessions: services.sessions,
  );
});
