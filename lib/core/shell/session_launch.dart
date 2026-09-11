import 'package:flutter/foundation.dart';

import '../../shared/models/enums.dart';
import 'multiplexer.dart';
import 'multiplexer_session.dart';
import 'shell_quoting.dart';

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
    this.multiplexer,
    this.tmuxSessionName,
    this.workingDirectory,
  });

  final SessionMode mode;

  /// Backend anchoring this session. Null for a direct shell.
  final MultiplexerKind? multiplexer;

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
  const SessionLaunchBuilder({
    required this.platform,
    required this.prefix,
    this.multiplexer = MultiplexerKind.tmux,
  });

  final RemotePlatform platform;

  /// Prefix for managed session names, from preferences.
  final String prefix;

  /// Backend used for persistent sessions on this host.
  final MultiplexerKind multiplexer;

  ShellQuoter get quoter => ShellQuoter.forPlatform(platform);

  Multiplexer get backend => Multiplexer.of(multiplexer, quoter: quoter);

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

  /// Attaches to (or creates) a managed multiplexer session.
  ///
  /// Throws [MultiplexerUnavailableException] for platforms without one so
  /// callers cannot accidentally emit `tmux ...` at a PowerShell prompt.
  ///
  /// A backend that cannot take a startup command (Herdr) gets the command
  /// typed into the attached session instead of appended to the attach line.
  /// Same reasoning as [directCommand]: a command that fails leaves the user at
  /// a usable prompt rather than tearing down the session they just opened.
  SessionLaunchPlan persistentSession({
    required String sessionName,
    String? workingDirectory,
    String? command,
  }) {
    if (!platform.supportsMultiplexer) {
      throw MultiplexerUnavailableException(multiplexer);
    }

    final backend = this.backend;
    final hasCommand = command != null && command.trim().isNotEmpty;

    if (hasCommand && backend.supportsStartupCommand) {
      return SessionLaunchPlan(
        mode: SessionMode.persistent,
        shellCommand: backend.attachOrCreateRunning(
          sessionName,
          command,
          workingDirectory: workingDirectory,
        ),
        multiplexer: multiplexer,
        tmuxSessionName: sessionName,
        workingDirectory: workingDirectory,
      );
    }

    return SessionLaunchPlan(
      mode: SessionMode.persistent,
      shellCommand: backend.attachOrCreate(
        sessionName,
        workingDirectory: workingDirectory,
      ),
      initialInput: hasCommand ? '$command\n' : null,
      multiplexer: multiplexer,
      tmuxSessionName: sessionName,
      workingDirectory: workingDirectory,
    );
  }

  /// Reattaches to an existing managed session without creating a new one.
  SessionLaunchPlan resumeSession(String sessionName) {
    if (!platform.supportsMultiplexer) {
      throw MultiplexerUnavailableException(multiplexer);
    }
    return SessionLaunchPlan(
      mode: SessionMode.persistent,
      shellCommand: backend.attachOrCreate(sessionName),
      multiplexer: multiplexer,
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
  }) => backend.managedSessionName(
    prefix: prefix,
    subject: subject,
    action: action,
    existingNames: existingNames,
  );
}
