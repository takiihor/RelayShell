import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../shared/models/models.dart';
import 'database/app_database.dart';
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
import 'security/biometric_gate.dart';
import 'security/ssh_key_material.dart';
import 'ssh/connection_manager.dart';
import 'ssh/credential_resolver.dart';
import 'ssh/forwarding_service.dart';
import 'ssh/host_key_verifier.dart';
import 'ssh/sftp_service.dart';
import 'ssh/tmux_service.dart';
import 'storage/config_transfer.dart';
import 'storage/secret_store.dart';

/// Everything the app needs, wired together once at startup (SPEC 41).
///
/// Constructed before the first frame so the UI never has to handle a
/// half-initialised database. Startup work is deliberately small: open storage,
/// read preferences, and stop. No SSH connection is attempted, and no host
/// status is probed until a screen actually shows one.
class AppServices {
  AppServices._({
    required this.database,
    required this.hosts,
    required this.credentials,
    required this.trustedKeys,
    required this.projects,
    required this.commands,
    required this.sessions,
    required this.forwards,
    required this.wol,
    required this.preferencesRepository,
    required this.terminalProfiles,
    required this.recents,
    required this.secrets,
    required this.biometrics,
    required this.appLock,
    required this.keyMaterial,
    required this.connections,
    required this.forwarding,
    required this.sftp,
    required this.tmux,
    required this.configTransfer,
    required this.wakeLock,
    required this.clipboard,
    required this.reachability,
    required this.initialPreferences,
  });

  final AppDatabase database;

  final HostsRepository hosts;
  final CredentialsRepository credentials;
  final TrustedKeysRepository trustedKeys;
  final ProjectsRepository projects;
  final CommandsRepository commands;
  final SessionsRepository sessions;
  final ForwardsRepository forwards;
  final WolRepository wol;
  final PreferencesRepository preferencesRepository;
  final TerminalProfilesRepository terminalProfiles;
  final RecentsRepository recents;

  final SecretStore secrets;
  final BiometricGate biometrics;
  final AppLock appLock;
  final SshKeyMaterial keyMaterial;

  final ConnectionManager connections;
  final ForwardingService forwarding;
  final SftpService sftp;
  final TmuxService tmux;

  final ConfigTransfer configTransfer;

  final ScreenWakeLock wakeLock;
  final ClipboardGuard clipboard;
  final ReachabilityProbe reachability;

  /// Preferences as read at startup, so the first frame paints the right theme.
  final AppPreferences initialPreferences;

  /// Opens storage and builds the service graph.
  ///
  /// [promptForHostKey], [promptForSecret] and [promptForKeyboardInteractive]
  /// come from the UI layer, because trusting a host key or entering a
  /// passphrase are decisions only the user can make. They are injected rather
  /// than reached for so the core stays testable without a widget tree.
  static Future<AppServices> start({
    required HostKeyPrompt promptForHostKey,
    required SecretPrompt promptForSecret,
    required KeyboardInteractivePrompt promptForKeyboardInteractive,
    String? databasePath,
    SecretStore? secretStore,
    DatabaseFactory? databaseFactory,
  }) async {
    final database = await AppDatabase.open(
      path: databasePath,
      factory: databaseFactory,
    );

    final hosts = HostsRepository(database);
    final credentials = CredentialsRepository(database);
    final trustedKeys = TrustedKeysRepository(database);
    final projects = ProjectsRepository(database);
    final commands = CommandsRepository(database);
    final sessions = SessionsRepository(database);
    final forwards = ForwardsRepository(database);
    final wol = WolRepository(database);
    final preferencesRepository = PreferencesRepository(database);
    final terminalProfiles = TerminalProfilesRepository(database);
    final recents = RecentsRepository(database);

    final preferences = await preferencesRepository.load();

    final secrets = secretStore ?? PlatformSecretStore();
    final biometrics = BiometricGate();
    final appLock = AppLock(biometrics: biometrics)
      ..applyPreferences(preferences);

    final resolver = CredentialResolver(
      credentials: credentials,
      secrets: secrets,
      biometrics: biometrics,
      promptForSecret: promptForSecret,
      promptForKeyboardInteractive: promptForKeyboardInteractive,
    );

    final verifier = HostKeyVerifier(
      trustedKeys: trustedKeys,
      prompt: promptForHostKey,
    );

    final connections = ConnectionManager(
      hosts: hosts,
      credentials: resolver,
      verifier: verifier,
      preferences: preferences,
    );

    return AppServices._(
      database: database,
      hosts: hosts,
      credentials: credentials,
      trustedKeys: trustedKeys,
      projects: projects,
      commands: commands,
      sessions: sessions,
      forwards: forwards,
      wol: wol,
      preferencesRepository: preferencesRepository,
      terminalProfiles: terminalProfiles,
      recents: recents,
      secrets: secrets,
      biometrics: biometrics,
      appLock: appLock,
      keyMaterial: const SshKeyMaterial(),
      connections: connections,
      forwarding: ForwardingService(),
      sftp: const SftpService(),
      tmux: const TmuxService(),
      configTransfer: ConfigTransfer(
        hosts: hosts,
        projects: projects,
        commands: commands,
        forwards: forwards,
        wol: wol,
        sessions: sessions,
        preferences: preferencesRepository,
      ),
      wakeLock: ScreenWakeLock(),
      clipboard: ClipboardGuard(),
      reachability: ReachabilityProbe(),
      initialPreferences: preferences,
    );
  }

  /// Deletes every local record and secret (SPEC 21 "Reset app").
  ///
  /// Connections are closed first: leaving a live session pointing at a host
  /// row that no longer exists is how a "reset" turns into a crash.
  Future<void> resetEverything() async {
    await connections.disconnectAll();
    await forwarding.stopAll();
    await database.deleteAllRows();
    await secrets.deleteAll();
    hosts.notifyChanged();
    credentials.notifyChanged();
    trustedKeys.notifyChanged();
    projects.notifyChanged();
    commands.notifyChanged();
    sessions.notifyChanged();
    forwards.notifyChanged();
    wol.notifyChanged();
    preferencesRepository.notifyChanged();
    terminalProfiles.notifyChanged();
    recents.notifyChanged();
  }

  @visibleForTesting
  Future<void> dispose() async {
    await connections.dispose();
    await forwarding.dispose();
    await reachability.dispose();
    await wakeLock.releaseAll();
    clipboard.dispose();
    await database.close();
  }
}
