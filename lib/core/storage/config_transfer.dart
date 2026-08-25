import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/models.dart';
import '../database/commands_repository.dart';
import '../database/forwards_repository.dart';
import '../database/hosts_repository.dart';
import '../database/preferences_repository.dart';
import '../database/projects_repository.dart';
import '../database/sessions_repository.dart';

/// What an import actually changed.
@immutable
class ImportSummary {
  const ImportSummary({
    this.hosts = 0,
    this.projects = 0,
    this.commands = 0,
    this.forwards = 0,
    this.sessions = 0,
    this.wolProfiles = 0,
    this.preferencesRestored = false,
    this.warnings = const [],
  });

  final int hosts;
  final int projects;
  final int commands;
  final int forwards;
  final int sessions;
  final int wolProfiles;
  final bool preferencesRestored;

  /// Non-fatal problems, e.g. a project whose host was not in the file.
  final List<String> warnings;

  int get total =>
      hosts + projects + commands + forwards + sessions + wolProfiles;
}

/// Raised when a backup file cannot be read.
class ConfigImportException implements Exception {
  const ConfigImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Exports and imports non-secret configuration (SPEC 22).
///
/// Private keys, passwords and passphrases are **never** written to an export.
/// Hosts are exported with their authentication *method* but not their
/// credential, so an imported host prompts the user to pick a credential rather
/// than silently appearing ready to connect (SPEC 22, 44.4).
class ConfigTransfer {
  ConfigTransfer({
    required this.hosts,
    required this.projects,
    required this.commands,
    required this.forwards,
    required this.wol,
    required this.sessions,
    required this.preferences,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final HostsRepository hosts;
  final ProjectsRepository projects;
  final CommandsRepository commands;
  final ForwardsRepository forwards;
  final WolRepository wol;
  final SessionsRepository sessions;
  final PreferencesRepository preferences;
  final Uuid _uuid;

  static const int formatVersion = 1;
  static const String formatName = 'relayshell.config';

  /// Builds the export document.
  ///
  /// Includes hosts, projects, commands, forwards, Wake-on-LAN settings,
  /// session metadata and UI preferences — everything needed to rebuild a
  /// setup on a new phone except the secrets, which the user re-supplies.
  Future<Map<String, Object?>> export() async {
    final allHosts = await hosts.all();
    final allProjects = await projects.all();
    final allCommands = await commands.all();
    final allForwards = await forwards.all();
    final allWol = await wol.all();
    final allSessions = await sessions.all();
    final prefs = await preferences.load();

    return {
      'format': formatName,
      'version': formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'contains_secrets': false,
      'hosts': allHosts.map((host) => host.toExportJson()).toList(),
      'projects': allProjects.map((project) => project.toExportJson()).toList(),
      'commands': allCommands.map((command) => command.toExportJson()).toList(),
      'port_forwards': allForwards
          .map((forward) => forward.toExportJson())
          .toList(),
      'wol_profiles': allWol.map((profile) => profile.toExportJson()).toList(),
      'sessions': allSessions.map((session) => session.toExportJson()).toList(),
      'preferences': prefs.toMap(),
    };
  }

  /// Serialises the export as indented JSON, ready to write to a file.
  Future<String> exportToJson() async =>
      const JsonEncoder.withIndent('  ').convert(await export());

  /// A default file name including the date, so successive backups do not
  /// silently overwrite each other.
  static String suggestedFileName({DateTime? now}) {
    final date = now ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'relayshell-backup-'
        '${date.year}${two(date.month)}${two(date.day)}.json';
  }

  /// Restores a backup document.
  ///
  /// Every record is given a fresh id and cross-references are remapped, so
  /// importing into a device that already has data merges rather than
  /// overwriting. [replaceExisting] is not offered here on purpose: destroying
  /// a working setup should go through the explicit "Reset app" action.
  Future<ImportSummary> import(
    String jsonText, {
    bool includePreferences = true,
  }) async {
    final Map<String, Object?> document;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, Object?>) {
        throw const ConfigImportException(
          'That file is not a RelayShell backup.',
        );
      }
      document = decoded;
    } on FormatException {
      throw const ConfigImportException('That file is not valid JSON.');
    }

    if (document['format'] != formatName) {
      throw const ConfigImportException(
        'That file is not a RelayShell backup.',
      );
    }
    final version = (document['version'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      throw ConfigImportException(
        'This backup was made by a newer version of the app '
        '(format $version). Update the app, then import again.',
      );
    }

    late final ImportSummary summary;
    try {
      summary = await hosts.database.transaction((txn) async {
        final warnings = <String>[];
        final hostIdMap = <String, String>{};
        final projectIdMap = <String, String>{};

        var hostCount = 0;
        for (final entry in _listOf(document['hosts'])) {
          final oldId = entry['id'] as String?;
          final newId = _uuid.v4();
          final host = Host.fromExportJson(entry, id: newId);
          if (host.hostname.isEmpty || host.username.isEmpty) {
            warnings.add('Skipped a computer with no hostname or username.');
            continue;
          }
          await txn.insert(HostsRepository.table, host.toRow());
          if (oldId != null) hostIdMap[oldId] = newId;
          hostCount++;
        }

        var projectCount = 0;
        for (final entry in _listOf(document['projects'])) {
          final oldId = entry['id'] as String?;
          final oldHostId = entry['host_id'] as String?;
          final newHostId = oldHostId == null ? null : hostIdMap[oldHostId];
          if (newHostId == null) {
            warnings.add(
              'Skipped project "${entry['name'] ?? 'unnamed'}" because its '
              'computer was not in the backup.',
            );
            continue;
          }
          final newId = _uuid.v4();
          await txn.insert(
            ProjectsRepository.table,
            Project.fromExportJson(entry, id: newId, hostId: newHostId).toRow(),
          );
          if (oldId != null) projectIdMap[oldId] = newId;
          projectCount++;
        }

        var commandCount = 0;
        for (final entry in _listOf(document['commands'])) {
          final scope = CommandScope.fromStorage(entry['scope'] as String?);
          final oldHostId = entry['host_id'] as String?;
          final oldProjectId = entry['project_id'] as String?;
          final newHostId = oldHostId == null ? null : hostIdMap[oldHostId];
          final newProjectId = oldProjectId == null
              ? null
              : projectIdMap[oldProjectId];

          // A scoped command whose owner did not survive would become invisible;
          // promote it to global so the user keeps the command itself.
          var effectiveScope = scope;
          if (scope == CommandScope.host && newHostId == null) {
            effectiveScope = CommandScope.global;
            warnings.add(
              'Command "${entry['name'] ?? 'unnamed'}" became a global command '
              'because its computer was not in the backup.',
            );
          }
          if (scope == CommandScope.project && newProjectId == null) {
            effectiveScope = CommandScope.global;
            warnings.add(
              'Command "${entry['name'] ?? 'unnamed'}" became a global command '
              'because its project was not in the backup.',
            );
          }

          final command = SavedCommand.fromExportJson(
            entry,
            id: _uuid.v4(),
            hostId: effectiveScope == CommandScope.host ? newHostId : null,
            projectId: effectiveScope == CommandScope.project
                ? newProjectId
                : null,
          ).copyWith(scope: effectiveScope);

          if (command.command.trim().isEmpty) {
            warnings.add('Skipped an empty command.');
            continue;
          }
          await txn.insert(CommandsRepository.table, command.toRow());
          commandCount++;
        }

        var forwardCount = 0;
        for (final entry in _listOf(document['port_forwards'])) {
          final oldHostId = entry['host_id'] as String?;
          final newHostId = oldHostId == null ? null : hostIdMap[oldHostId];
          if (newHostId == null) continue;
          final now = DateTime.now();
          await txn.insert(
            ForwardsRepository.table,
            PortForwardProfile(
              id: _uuid.v4(),
              hostId: newHostId,
              name: (entry['name'] as String?) ?? 'Imported forward',
              type: ForwardType.fromStorage(entry['type'] as String?),
              listenPort: (entry['listen_port'] as num?)?.toInt() ?? 0,
              listenAddress:
                  (entry['listen_address'] as String?) ?? '127.0.0.1',
              targetHost: entry['target_host'] as String?,
              targetPort: (entry['target_port'] as num?)?.toInt(),
              autoStart: entry['auto_start'] == true,
              createdAt: now,
              updatedAt: now,
            ).toRow(),
          );
          forwardCount++;
        }

        var wolCount = 0;
        for (final entry in _listOf(document['wol_profiles'])) {
          final oldHostId = entry['host_id'] as String?;
          final newHostId = oldHostId == null ? null : hostIdMap[oldHostId];
          final mac = entry['mac_address'] as String?;
          if (newHostId == null || mac == null) continue;
          await txn.insert(
            WolRepository.table,
            WolProfile(
              hostId: newHostId,
              macAddress: mac,
              broadcastAddress:
                  (entry['broadcast_address'] as String?) ?? '255.255.255.255',
              port: (entry['port'] as num?)?.toInt() ?? 9,
            ).toRow(),
          );
          wolCount++;
        }

        var sessionCount = 0;
        for (final entry in _listOf(document['sessions'])) {
          final oldHostId = entry['host_id'] as String?;
          final newHostId = oldHostId == null ? null : hostIdMap[oldHostId];
          if (newHostId == null) continue;
          final oldProjectId = entry['project_id'] as String?;
          final now = DateTime.now();
          await txn.insert(
            SessionsRepository.table,
            SessionRecord(
              id: _uuid.v4(),
              hostId: newHostId,
              projectId: oldProjectId == null
                  ? null
                  : projectIdMap[oldProjectId],
              tmuxSessionName: entry['tmux_session_name'] as String?,
              displayName:
                  (entry['display_name'] as String?) ?? 'Imported session',
              mode: SessionMode.fromStorage(entry['mode'] as String?),
              workingDirectory: entry['working_directory'] as String?,
              createdAt: now,
              lastUsedAt: now,
            ).toRow(),
          );
          sessionCount++;
        }

        var preferencesRestored = false;
        if (includePreferences) {
          final raw = document['preferences'];
          if (raw is Map) {
            final map = <String, String>{
              for (final entry in raw.entries)
                entry.key.toString(): entry.value.toString(),
            };
            for (final entry in AppPreferences.fromMap(map).toMap().entries) {
              await txn.insert(PreferencesRepository.table, {
                'key': entry.key,
                'value': entry.value,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            preferencesRestored = true;
          }
        }

        return ImportSummary(
          hosts: hostCount,
          projects: projectCount,
          commands: commandCount,
          forwards: forwardCount,
          sessions: sessionCount,
          wolProfiles: wolCount,
          preferencesRestored: preferencesRestored,
          warnings: warnings,
        );
      });
    } on ConfigImportException {
      rethrow;
    } on Object {
      throw const ConfigImportException(
        'That backup contains invalid configuration data.',
      );
    }

    hosts.notifyChanged();
    projects.notifyChanged();
    commands.notifyChanged();
    forwards.notifyChanged();
    wol.notifyChanged();
    sessions.notifyChanged();
    preferences.notifyChanged();
    return summary;
  }

  static List<Map<String, Object?>> _listOf(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, Object?>>().toList();
  }
}
