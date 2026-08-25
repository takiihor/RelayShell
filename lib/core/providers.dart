import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'bootstrap.dart';
import 'database/commands_repository.dart';
import 'database/credentials_repository.dart';
import 'database/forwards_repository.dart';
import 'database/hosts_repository.dart';
import 'database/preferences_repository.dart';
import 'database/projects_repository.dart';
import 'database/sessions_repository.dart';
import 'database/trusted_keys_repository.dart';
import 'platform/device_services.dart';
import 'security/app_lock.dart';
import 'security/ssh_key_material.dart';
import 'ssh/connection_manager.dart';
import 'ssh/forwarding_service.dart';
import 'ssh/sftp_service.dart';
import 'ssh/ssh_connection.dart';
import 'ssh/tmux_service.dart';
import 'storage/config_transfer.dart';
import 'storage/secret_store.dart';
import '../shared/models/models.dart';

/// The wired service graph. Overridden in `main` with the real instance
/// (SPEC 26: one state-management approach, no service locator alongside it).
final appServicesProvider = Provider<AppServices>(
  (ref) => throw StateError('AppServices must be provided before use.'),
);

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final hostsRepositoryProvider = Provider<HostsRepository>(
  (ref) => ref.watch(appServicesProvider).hosts,
);

final credentialsRepositoryProvider = Provider<CredentialsRepository>(
  (ref) => ref.watch(appServicesProvider).credentials,
);

final trustedKeysRepositoryProvider = Provider<TrustedKeysRepository>(
  (ref) => ref.watch(appServicesProvider).trustedKeys,
);

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ref.watch(appServicesProvider).projects,
);

final commandsRepositoryProvider = Provider<CommandsRepository>(
  (ref) => ref.watch(appServicesProvider).commands,
);

final sessionsRepositoryProvider = Provider<SessionsRepository>(
  (ref) => ref.watch(appServicesProvider).sessions,
);

final forwardsRepositoryProvider = Provider<ForwardsRepository>(
  (ref) => ref.watch(appServicesProvider).forwards,
);

final wolRepositoryProvider = Provider<WolRepository>(
  (ref) => ref.watch(appServicesProvider).wol,
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => ref.watch(appServicesProvider).preferencesRepository,
);

final terminalProfilesRepositoryProvider = Provider<TerminalProfilesRepository>(
  (ref) => ref.watch(appServicesProvider).terminalProfiles,
);

final recentsRepositoryProvider = Provider<RecentsRepository>(
  (ref) => ref.watch(appServicesProvider).recents,
);

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final secretStoreProvider = Provider<SecretStore>(
  (ref) => ref.watch(appServicesProvider).secrets,
);

final keyMaterialProvider = Provider<SshKeyMaterial>(
  (ref) => ref.watch(appServicesProvider).keyMaterial,
);

final connectionManagerProvider = Provider<ConnectionManager>(
  (ref) => ref.watch(appServicesProvider).connections,
);

final forwardingServiceProvider = Provider<ForwardingService>(
  (ref) => ref.watch(appServicesProvider).forwarding,
);

final sftpServiceProvider = Provider<SftpService>(
  (ref) => ref.watch(appServicesProvider).sftp,
);

final tmuxServiceProvider = Provider<TmuxService>(
  (ref) => ref.watch(appServicesProvider).tmux,
);

final configTransferProvider = Provider<ConfigTransfer>(
  (ref) => ref.watch(appServicesProvider).configTransfer,
);

final appLockProvider = ChangeNotifierProvider<AppLock>(
  (ref) => ref.watch(appServicesProvider).appLock,
);

final wakeLockProvider = Provider<ScreenWakeLock>(
  (ref) => ref.watch(appServicesProvider).wakeLock,
);

final clipboardGuardProvider = Provider<ClipboardGuard>(
  (ref) => ref.watch(appServicesProvider).clipboard,
);

final reachabilityProbeProvider = Provider<ReachabilityProbe>(
  (ref) => ref.watch(appServicesProvider).reachability,
);

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------

/// Live preferences. Seeded with the value read at startup so the very first
/// build already has the user's theme rather than flashing the default.
final preferencesProvider =
    NotifierProvider<PreferencesController, AppPreferences>(
      PreferencesController.new,
    );

class PreferencesController extends Notifier<AppPreferences> {
  StreamSubscription<AppPreferences>? _subscription;

  @override
  AppPreferences build() {
    final services = ref.watch(appServicesProvider);
    final repository = ref.watch(preferencesRepositoryProvider);

    _subscription = repository.watchPreferences().listen((preferences) {
      state = preferences;
      // Connections opened from now on pick up the new SSH settings.
      services.connections.updatePreferences(preferences);
      services.appLock.applyPreferences(preferences);
    });
    ref.onDispose(() => _subscription?.cancel());

    return services.initialPreferences;
  }

  Future<void> update(AppPreferences preferences) async {
    state = preferences;
    await ref.read(preferencesRepositoryProvider).save(preferences);
  }

  /// Applies one change without the caller rebuilding the whole object.
  Future<void> edit(AppPreferences Function(AppPreferences current) change) =>
      update(change(state));
}

// ---------------------------------------------------------------------------
// Live data
// ---------------------------------------------------------------------------

final hostsProvider = StreamProvider<List<Host>>(
  (ref) => ref.watch(hostsRepositoryProvider).watchAll(),
);

final recentHostsProvider = StreamProvider<List<Host>>(
  (ref) => ref.watch(hostsRepositoryProvider).watchRecent(),
);

final hostProvider = StreamProvider.family<Host?, String>(
  (ref, id) => ref.watch(hostsRepositoryProvider).watchById(id),
);

final projectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectsRepositoryProvider).watchAll(),
);

final recentProjectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectsRepositoryProvider).watchRecent(),
);

final projectProvider = StreamProvider.family<Project?, String>(
  (ref, id) => ref.watch(projectsRepositoryProvider).watchById(id),
);

final projectsForHostProvider = StreamProvider.family<List<Project>, String>(
  (ref, hostId) => ref.watch(projectsRepositoryProvider).watchForHost(hostId),
);

final credentialsProvider = StreamProvider<List<Credential>>(
  (ref) => ref.watch(credentialsRepositoryProvider).watchAll(),
);

final credentialProvider = StreamProvider.family<Credential?, String>(
  (ref, id) => ref.watch(credentialsRepositoryProvider).watchById(id),
);

final commandsProvider = StreamProvider<List<SavedCommand>>(
  (ref) => ref.watch(commandsRepositoryProvider).watchAll(),
);

final favoriteCommandsProvider = StreamProvider<List<SavedCommand>>(
  (ref) => ref.watch(commandsRepositoryProvider).watchFavorites(),
);

/// Commands visible in a given host/project context.
final scopedCommandsProvider =
    StreamProvider.family<List<SavedCommand>, CommandScopeQuery>(
      (ref, query) => ref
          .watch(commandsRepositoryProvider)
          .watchVisibleIn(hostId: query.hostId, projectId: query.projectId),
    );

/// Identifies a command scope. Value equality matters: `family` caches by it,
/// and two equal queries must share one subscription.
class CommandScopeQuery {
  const CommandScopeQuery({this.hostId, this.projectId});

  final String? hostId;
  final String? projectId;

  @override
  bool operator ==(Object other) =>
      other is CommandScopeQuery &&
      other.hostId == hostId &&
      other.projectId == projectId;

  @override
  int get hashCode => Object.hash(hostId, projectId);
}

final sessionRecordsProvider = StreamProvider<List<SessionRecord>>(
  (ref) => ref.watch(sessionsRepositoryProvider).watchAll(),
);

final recentSessionsProvider = StreamProvider<List<SessionRecord>>(
  (ref) => ref.watch(sessionsRepositoryProvider).watchRecent(),
);

final sessionsForHostProvider =
    StreamProvider.family<List<SessionRecord>, String>(
      (ref, hostId) =>
          ref.watch(sessionsRepositoryProvider).watchForHost(hostId),
    );

final trustedKeysProvider = StreamProvider<List<TrustedHostKey>>(
  (ref) => ref.watch(trustedKeysRepositoryProvider).watchAll(),
);

final forwardProfilesProvider = StreamProvider<List<PortForwardProfile>>(
  (ref) => ref.watch(forwardsRepositoryProvider).watchAll(),
);

final forwardProfilesForHostProvider =
    StreamProvider.family<List<PortForwardProfile>, String>(
      (ref, hostId) =>
          ref.watch(forwardsRepositoryProvider).watchForHost(hostId),
    );

final wolProfileProvider = StreamProvider.family<WolProfile?, String>(
  (ref, hostId) => ref.watch(wolRepositoryProvider).watchForHost(hostId),
);

// ---------------------------------------------------------------------------
// Connection state
// ---------------------------------------------------------------------------

/// Emits whenever any connection is added, removed or changes state.
final connectionChangesProvider = StreamProvider<void>(
  (ref) => ref.watch(connectionManagerProvider).changes,
);

/// The live connection for a host, or null when there is none.
final hostConnectionProvider = Provider.family<SshConnection?, String>((
  ref,
  hostId,
) {
  ref.watch(connectionChangesProvider);
  return ref.watch(connectionManagerProvider).connectionFor(hostId);
});

/// Connection status for a host, following reconnects.
final hostConnectionStatusProvider =
    StreamProvider.family<SshConnectionStatus, String>((ref, hostId) {
      ref.watch(connectionChangesProvider);
      final connection = ref
          .watch(connectionManagerProvider)
          .connectionFor(hostId);
      if (connection == null) {
        return Stream.value(
          const SshConnectionStatus(state: SshConnectionState.idle),
        );
      }
      return connection.statusStream;
    });

/// Advisory reachability, refreshed only when a screen asks for it (SPEC 7.2).
final hostReachabilityProvider = Provider.family<HostReachability, String>((
  ref,
  hostId,
) {
  ref.watch(reachabilityChangesProvider);
  return ref.watch(reachabilityProbeProvider).statusFor(hostId);
});

final reachabilityChangesProvider = StreamProvider<void>(
  (ref) => ref.watch(reachabilityProbeProvider).changes,
);

final activeForwardsProvider = StreamProvider<List<ActiveForward>>((
  ref,
) async* {
  final service = ref.watch(forwardingServiceProvider);
  yield service.active;
  yield* service.changes.map((_) => service.active);
});
