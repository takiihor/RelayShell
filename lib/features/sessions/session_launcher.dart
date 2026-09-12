import 'package:flutter/foundation.dart';

import '../../core/database/commands_repository.dart';
import '../../core/database/hosts_repository.dart';
import '../../core/database/projects_repository.dart';
import '../../core/database/sessions_repository.dart';
import '../../core/shell/command_variables.dart';
import '../../core/shell/danger_analysis.dart';
import '../../core/shell/session_launch.dart';
import '../../core/shell/shell_quoting.dart';
import '../../core/shell/multiplexer_session.dart';
import '../../core/ssh/connection_manager.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../core/ssh/herdr_service.dart';
import '../../shared/models/models.dart';
import '../terminal/terminal_manager.dart';
import '../terminal/terminal_session.dart';

/// A command that has been resolved and checked, ready to confirm and run.
@immutable
class PreparedCommand {
  const PreparedCommand({
    required this.command,
    required this.resolved,
    required this.host,
    required this.danger,
    required this.needsConfirmation,
    this.project,
    this.workingDirectory,
  });

  final SavedCommand command;

  /// The command text after variable substitution — exactly what will run.
  final String resolved;

  final Host host;
  final Project? project;
  final String? workingDirectory;

  final DangerAssessment danger;

  /// Whether the user must confirm before this runs.
  final bool needsConfirmation;
}

/// Outcome of a one-shot command (SPEC 12.4).
@immutable
class OneShotResult {
  const OneShotResult({
    required this.command,
    required this.output,
    required this.exitCode,
  });

  final String command;
  final String output;
  final int? exitCode;

  bool get succeeded => exitCode == 0;
}

/// A one-shot command in progress. Cancellation closes only its exec channel;
/// terminals and file transfers sharing the host connection keep running.
class OneShotExecution {
  OneShotExecution._({required this.completion, required this._cancel});

  final Future<OneShotResult> completion;
  final void Function() _cancel;

  void cancel() => _cancel();
}

/// Raised when a launch cannot proceed and the UI must explain why.
class LaunchException implements Exception {
  const LaunchException(this.message, {this.action});

  final String message;
  final String? action;

  @override
  String toString() => message;
}

/// Turns products concepts — a project, an action, a saved session — into
/// running terminals (SPEC 12.3, 13, 14, 40).
///
/// This is where the app stops being an SSH client and starts being a control
/// centre: every path here ends in the user looking at the thing they wanted,
/// without typing `ssh`, `cd` or `tmux attach`.
class SessionLauncher {
  const SessionLauncher({
    required this.terminals,
    required this.connections,
    required this.hosts,
    required this.projects,
    required this.commands,
    required this.sessions,
    this.variables = const CommandVariableResolver(),
    this.danger = const DangerAnalyzer(),
  });

  final TerminalManager terminals;
  final ConnectionManager connections;
  final HostsRepository hosts;
  final ProjectsRepository projects;
  final CommandsRepository commands;
  final SessionsRepository sessions;
  final CommandVariableResolver variables;
  final DangerAnalyzer danger;

  SessionLaunchBuilder _builderFor(Host host, AppPreferences preferences) =>
      SessionLaunchBuilder(
        platform: host.platform,
        prefix: preferences.tmuxSessionPrefix,
        multiplexer: host.multiplexer,
      );

  /// Opens a plain terminal on [host] (SPEC 8.5 "Open Terminal").
  Future<TerminalSession> openHostTerminal({
    required Host host,
    required AppPreferences preferences,
    SessionMode? mode,
  }) => _openHostTerminal(
    host: host,
    preferences: preferences,
    mode: mode,
    reuseExisting: true,
  );

  /// Opens another independent terminal, even if an equivalent tab is live.
  Future<TerminalSession> openAdditionalHostTerminal({
    required Host host,
    required AppPreferences preferences,
    SessionMode? mode,
  }) => _openHostTerminal(
    host: host,
    preferences: preferences,
    mode: mode,
    reuseExisting: false,
  );

  Future<TerminalSession> _openHostTerminal({
    required Host host,
    required AppPreferences preferences,
    required SessionMode? mode,
    required bool reuseExisting,
  }) async {
    final builder = _builderFor(host, preferences);
    final effectiveMode = _resolveMode(
      requested: mode ?? preferences.defaultSessionMode,
      host: host,
    );

    final plan = switch (effectiveMode) {
      SessionMode.direct => builder.directShell(
        workingDirectory: host.startupDirectory,
      ),
      SessionMode.persistent => builder.persistentSession(
        sessionName: reuseExisting
            ? builder.sessionNameFor(subject: host.name, action: 'shell')
            : await terminals.managedNameFor(
                host: host,
                subject: host.name,
                prefix: preferences.tmuxSessionPrefix,
                action: 'shell',
              ),
        workingDirectory: host.startupDirectory,
      ),
    };

    if (reuseExisting) {
      final open = terminals.findMatching(hostId: host.id, plan: plan);
      if (open != null) {
        terminals.setActive(open.id);
        if (open.canReconnect) await open.reconnect();
        return open;
      }
    }

    return terminals.open(
      host: host,
      plan: plan,
      preferences: preferences,
      title: host.name,
    );
  }

  /// Opens a project at its remote path (SPEC 12.3, 40.3).
  Future<TerminalSession> openProject({
    required Project project,
    required Host host,
    required AppPreferences preferences,
    SessionMode? mode,
    String? runCommand,
    String? actionLabel,
  }) async {
    final builder = _builderFor(host, preferences);
    final effectiveMode = _resolveMode(
      requested: mode ?? project.defaultSessionMode,
      host: host,
    );

    final SessionLaunchPlan plan;
    switch (effectiveMode) {
      case SessionMode.direct:
        plan = runCommand == null
            ? builder.directShell(workingDirectory: project.remotePath)
            : builder.directCommand(
                runCommand,
                workingDirectory: project.remotePath,
              );
      case SessionMode.persistent:
        final name = project.defaultTmuxName?.trim().isNotEmpty ?? false
            ? project.defaultTmuxName!.trim()
            : await terminals.managedNameFor(
                host: host,
                subject: project.name,
                prefix: preferences.tmuxSessionPrefix,
                action: actionLabel,
              );
        plan = builder.persistentSession(
          sessionName: name,
          workingDirectory: project.remotePath,
          command: runCommand,
        );
    }

    await projects.markOpened(project.id);

    return terminals.open(
      host: host,
      project: project,
      plan: plan,
      preferences: preferences,
      title: actionLabel == null
          ? project.name
          : '${project.name} — $actionLabel',
    );
  }

  /// Reattaches to a saved session (SPEC 11.5, 40.4).
  ///
  /// A persistent session reattaches to its tmux session, which is the whole
  /// point of the feature. A direct session has nothing left on the remote
  /// side, so it reopens a shell in the same directory instead — the honest
  /// approximation, not a pretence that the process survived.
  Future<TerminalSession> resumeSession({
    required SessionRecord record,
    required AppPreferences preferences,
  }) async {
    final host = await hosts.byId(record.hostId);
    if (host == null) {
      throw const LaunchException(
        'The computer for this session no longer exists.',
      );
    }

    final tmuxName = record.tmuxSessionName;
    if (tmuxName != null) {
      final open = terminals.findAttached(
        hostId: host.id,
        tmuxSessionName: tmuxName,
        herdrTerminalId: record.herdrTerminalId,
      );
      if (open != null) {
        terminals.setActive(open.id);
        if (open.canReconnect) await open.reconnect();
        await sessions.touch(record.id);
        return open;
      }
    }

    final project = record.projectId == null
        ? null
        : await projects.byId(record.projectId!);

    final builder = _builderFor(host, preferences);

    final SessionLaunchPlan plan;
    if (record.herdrTerminalId != null) {
      if (tmuxName == null || !host.platform.supportsMultiplexer) {
        throw const LaunchException(
          'This Herdr pane requires its original POSIX computer and session.',
        );
      }
      plan = HerdrService.attach(tmuxName, record.herdrTerminalId!);
    } else if (record.isPersistent && host.platform.supportsMultiplexer) {
      plan = builder.resumeSession(tmuxName!);
    } else {
      plan = record.launchCommand == null
          ? builder.directShell(workingDirectory: record.workingDirectory)
          : builder.directCommand(
              record.launchCommand!,
              workingDirectory: record.workingDirectory,
            );
    }

    final matching = terminals.findMatching(
      hostId: host.id,
      projectId: project?.id,
      plan: plan,
    );
    if (matching != null) {
      terminals.setActive(matching.id);
      if (matching.canReconnect) await matching.reconnect();
      await sessions.touch(record.id);
      return matching;
    }

    await sessions.touch(record.id);

    return terminals.open(
      host: host,
      project: project,
      plan: plan,
      preferences: preferences,
      title: record.displayName,
      sessionRecordId: record.id,
    );
  }

  /// Attaches to a tmux session discovered on the host but not yet saved
  /// locally (SPEC 11.3 "Attach").
  Future<TerminalSession> attachTmuxSession({
    required Host host,
    required MultiplexerSession session,
    required AppPreferences preferences,
  }) async {
    final open = terminals.findAttached(
      hostId: host.id,
      tmuxSessionName: session.name,
    );
    if (open != null) {
      terminals.setActive(open.id);
      if (open.canReconnect) await open.reconnect();
      return open;
    }

    final builder = _builderFor(host, preferences);
    return terminals.open(
      host: host,
      plan: builder.resumeSession(session.name),
      preferences: preferences,
      title: session.name,
    );
  }

  /// Resolves variables and safety checks for [command] before it runs
  /// (SPEC 13.2, 13.3).
  ///
  /// Returns a [PreparedCommand] holding exactly the text that will execute, so
  /// the confirmation dialog can show the real thing rather than the template.
  Future<PreparedCommand> prepare({
    required SavedCommand command,
    required Host host,
    Project? project,
    Map<String, String> inputs = const {},
  }) async {
    final workingDirectory =
        command.workingDirectory?.trim().isNotEmpty ?? false
        ? command.workingDirectory!.trim()
        : project?.remotePath ?? host.startupDirectory;

    final substitution = variables.resolve(
      command.command,
      context: {
        'project_path': project?.remotePath,
        'project_name': project?.name,
        'host_name': host.name,
        'host_hostname': host.hostname,
        'host_username': host.username,
        'working_directory': workingDirectory,
      },
      inputs: inputs,
    );

    if (!substitution.isComplete) {
      throw LaunchException(
        'This command still needs a value for '
        '${substitution.unresolved.join(', ')}.',
      );
    }

    final assessment = danger.analyze(substitution.command);
    final needsConfirmation = switch (command.confirmationMode) {
      ConfirmationMode.none => false,
      ConfirmationMode.always => true,
      ConfirmationMode.dangerous => assessment.hasSignals,
    };

    return PreparedCommand(
      command: command,
      resolved: substitution.command,
      host: host,
      project: project,
      workingDirectory: workingDirectory,
      danger: assessment,
      needsConfirmation: needsConfirmation,
    );
  }

  /// Placeholders the user must fill before [command] can run.
  List<CommandInputRequest> inputsFor(SavedCommand command) =>
      variables.inputsIn(command.command);

  /// Runs a prepared command in an interactive terminal (SPEC 13.1).
  Future<TerminalSession> runInteractive({
    required PreparedCommand prepared,
    required AppPreferences preferences,
    SessionMode? mode,
  }) async {
    final host = prepared.host;
    final project = prepared.project;
    final builder = _builderFor(host, preferences);
    final effectiveMode = _resolveMode(
      requested: mode ?? prepared.command.sessionMode,
      host: host,
    );

    final SessionLaunchPlan plan;
    switch (effectiveMode) {
      case SessionMode.direct:
        plan = builder.directCommand(
          prepared.resolved,
          workingDirectory: prepared.workingDirectory,
        );
      case SessionMode.persistent:
        plan = builder.persistentSession(
          sessionName: await terminals.managedNameFor(
            host: host,
            subject: project?.name ?? host.name,
            prefix: preferences.tmuxSessionPrefix,
            action: prepared.command.name,
          ),
          workingDirectory: prepared.workingDirectory,
          command: prepared.resolved,
        );
    }

    if (project != null) await projects.markOpened(project.id);

    return terminals.open(
      host: host,
      project: project,
      plan: plan,
      preferences: preferences,
      title: prepared.command.name,
    );
  }

  /// Starts a prepared command once with a bounded buffer and a cancellation
  /// handle for the result sheet (SPEC 12.4).
  OneShotExecution startOneShot({required PreparedCommand prepared}) {
    CommandExecution? command;
    var cancelled = false;

    void cancel() {
      cancelled = true;
      command?.cancel();
    }

    Future<OneShotResult> run() async {
      final connection = await connections.connect(prepared.host);
      if (cancelled) {
        throw const SshFailure(
          kind: SshFailureKind.closedByRemote,
          message: 'Command cancelled.',
        );
      }

      final builder = SessionLaunchBuilder(
        platform: prepared.host.platform,
        prefix: 'rdc',
        multiplexer: prepared.host.multiplexer,
      );

      final String remoteCommand;
      try {
        remoteCommand = builder.oneShot(
          prepared.resolved,
          workingDirectory: prepared.workingDirectory,
        );
      } on UnquotableArgumentError catch (error) {
        throw LaunchException(
          'The working directory cannot be used safely on this computer.',
          action: error.reason,
        );
      }

      command = connection.startCommand(
        remoteCommand,
        maxOutputBytes: 1024 * 1024,
        timeout: const Duration(minutes: 2),
      );
      if (cancelled) command!.cancel();
      final result = await command!.completion;
      await hosts.markConnected(prepared.host.id);

      return OneShotResult(
        command: prepared.resolved,
        output: result.combined,
        exitCode: result.exitCode,
      );
    }

    return OneShotExecution._(completion: run(), cancel: cancel);
  }

  /// Runs a prepared command once and returns its output (SPEC 12.4).
  Future<OneShotResult> runOneShot({required PreparedCommand prepared}) =>
      startOneShot(prepared: prepared).completion;

  /// Opens a connection without opening a terminal, e.g. for the file browser.
  Future<SshConnection> connectOnly(Host host) async {
    final connection = await connections.connect(host);
    await hosts.markConnected(host.id);
    return connection;
  }

  /// Falls back to a direct session when the host cannot run tmux (SPEC 30).
  ///
  /// Silently downgrading is right here: the alternative is refusing to open a
  /// terminal on a Windows machine because a *default* asked for tmux.
  SessionMode _resolveMode({
    required SessionMode requested,
    required Host host,
  }) {
    if (requested == SessionMode.persistent &&
        !host.platform.supportsMultiplexer) {
      return SessionMode.direct;
    }
    return requested;
  }
}
