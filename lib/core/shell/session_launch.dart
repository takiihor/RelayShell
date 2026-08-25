import 'package:flutter/foundation.dart';

import '../../shared/models/enums.dart';
import 'shell_quoting.dart';
import 'tmux.dart';

/// A fully-resolved description of what to run when a session opens.
///
/// Two shapes exist because SSH offers two ways in, and they behave
/// differently on failure:
///
/// * [shellCommand] `null` — open an interactive login shell, then optionally
///   type a command into it. The user keeps a shell if the command fails.
/// * [shellCommand] set — hand SSH one command to exec. Cheaper, but the
///   session ends when that command ends.
@immutable
class SessionLaunchPlan {
  const SessionLaunchPlan({
    required this.mode,
    this.shellCommand,
    this.initialInput,
    this.tmuxSessionName,
    this.workingDirectory,
  });

  final SessionMode mode;

  /// Command to exec instead of a login shell, already quoted.
  final String? shellCommand;

  /// Text to write into an interactive shell once it is ready, including the
  /// trailing newline.
  final String? initialInput;

  final String? tmuxSessionName;
  final String? workingDirectory;

  bool get usesExec => shellCommand != null;
}

/// Builds the remote command line for opening projects, sessions and actions
/// (SPEC 12.3, 13, 14).
///
/// Every path and session name that the app supplies is quoted through
/// [ShellQuoter]. The one deliberate exception is a user's saved command body,
/// which is intentional shell input (SPEC 29) and is passed through unchanged.
class SessionLaunchBuilder {
  const SessionLaunchBuilder({required this.platform, required this.prefix});

  final RemotePlatform platform;

  /// Prefix for managed tmux session names, from preferences.
  final String prefix;

  ShellQuoter get quoter => ShellQuoter.forPlatform(platform);

  TmuxCommandBuilder get tmux => TmuxCommandBuilder(quoter: quoter);

  /// Plain interactive shell, optionally starting in [workingDirectory].
  ///
  /// The `cd` is typed into the shell rather than exec'd with it so that a
  /// missing directory leaves the user at a usable prompt instead of
  /// disconnecting them.
  SessionLaunchPlan directShell({String? workingDirectory}) {
    return SessionLaunchPlan(
      mode: SessionMode.direct,
      initialInput: workingDirectory == null || workingDirectory.isEmpty
          ? null
          : '${quoter.changeDirectory(workingDirectory)}\n',
      workingDirectory: workingDirectory,
    );
  }

  /// Interactive shell that runs [command] after changing directory.
  SessionLaunchPlan directCommand(String command, {String? workingDirectory}) {
    final input = workingDirectory == null || workingDirectory.isEmpty
        ? command
        : quoter.andThen(quoter.changeDirectory(workingDirectory), command);
    return SessionLaunchPlan(
      mode: SessionMode.direct,
      initialInput: '$input\n',
      workingDirectory: workingDirectory,
    );
  }

  /// Attaches to (or creates) a managed tmux session.
  ///
  /// Throws [TmuxUnavailableException] for platforms without tmux so callers
  /// cannot accidentally emit `tmux ...` at a PowerShell prompt.
  SessionLaunchPlan persistentSession({
    required String sessionName,
    String? workingDirectory,
    String? command,
  }) {
    if (!platform.supportsTmux) throw const TmuxUnavailableException();

    final remote = command == null || command.trim().isEmpty
        ? tmux.attachOrCreate(sessionName, workingDirectory: workingDirectory)
        : tmux.attachOrCreateRunning(
            sessionName,
            command,
            workingDirectory: workingDirectory,
          );

    return SessionLaunchPlan(
      mode: SessionMode.persistent,
      shellCommand: remote,
      tmuxSessionName: sessionName,
      workingDirectory: workingDirectory,
    );
  }

  /// Reattaches to an existing managed session without creating a new one.
  SessionLaunchPlan resumeSession(String sessionName) {
    if (!platform.supportsTmux) throw const TmuxUnavailableException();
    return SessionLaunchPlan(
      mode: SessionMode.persistent,
      shellCommand: tmux.attachOrCreate(sessionName),
      tmuxSessionName: sessionName,
    );
  }

  /// Wraps a one-shot command so it runs in [workingDirectory] (SPEC 12.4).
  ///
  /// Used with `exec`, not an interactive shell, so the caller gets a clean
  /// exit code and captured output.
  String oneShot(String command, {String? workingDirectory}) {
    if (workingDirectory == null || workingDirectory.isEmpty) return command;
    return quoter.andThen(quoter.changeDirectory(workingDirectory), command);
  }

  /// Derives the managed session name for a project or host subject.
  String sessionNameFor({
    required String subject,
    String? action,
    Set<String> existingNames = const {},
  }) => TmuxCommandBuilder.managedSessionName(
    prefix: prefix,
    subject: subject,
    action: action,
    existingNames: existingNames,
  );
}
