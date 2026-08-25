import '../../shared/models/models.dart';
import '../shell/shell_quoting.dart';
import '../shell/tmux.dart';
import 'ssh_connection.dart';

/// Whether a remote machine can host persistent sessions.
class TmuxAvailability {
  const TmuxAvailability({required this.available, this.version, this.reason});

  const TmuxAvailability.unavailable(this.reason)
    : available = false,
      version = null;

  final bool available;

  /// e.g. `tmux 3.4`.
  final String? version;

  /// Why tmux cannot be used, when [available] is false.
  final String? reason;
}

/// Discovers and manages tmux sessions on a connected host (SPEC 11).
///
/// Everything here is read-or-attach. The app never installs tmux, never
/// changes tmux configuration, and never kills a session the user did not
/// explicitly ask to kill (SPEC 11.4).
class TmuxService {
  const TmuxService();

  /// Checks whether tmux exists on the far side.
  ///
  /// Windows hosts short-circuit: emitting `command -v tmux` at a PowerShell
  /// prompt produces a confusing error rather than a useful answer.
  Future<TmuxAvailability> detect(SshConnection connection) async {
    if (!connection.host.platform.supportsTmux) {
      return const TmuxAvailability.unavailable(
        'Persistent sessions use tmux, which is not available on Windows '
        'computers.',
      );
    }

    final builder = TmuxCommandBuilder(
      quoter: _quoterFor(connection.host.platform),
    );
    final result = await connection.run(builder.detect());
    final output = result.combined.trim();

    if (output.isEmpty || output.contains('__NO_TMUX__')) {
      return const TmuxAvailability.unavailable(
        'tmux is not installed on this computer.',
      );
    }
    return TmuxAvailability(available: true, version: output.split('\n').first);
  }

  /// Lists the sessions currently running on the host.
  ///
  /// Returns an empty list when tmux is present but has no sessions, and throws
  /// [TmuxUnavailableException] when tmux is missing, so callers can tell the
  /// two apart and offer a direct terminal instead (SPEC 11.4).
  Future<List<TmuxSession>> listSessions(SshConnection connection) async {
    if (!connection.host.platform.supportsTmux) {
      throw const TmuxUnavailableException();
    }

    final builder = TmuxCommandBuilder(
      quoter: _quoterFor(connection.host.platform),
    );
    final result = await connection.run(builder.listSessions());

    if (result.exitCode == 127) throw const TmuxUnavailableException();

    return builder.parseSessions(result.stdout);
  }

  /// Session names in use, for collision-free name generation.
  Future<Set<String>> sessionNames(SshConnection connection) async {
    try {
      final sessions = await listSessions(connection);
      return sessions.map((session) => session.name).toSet();
    } on TmuxUnavailableException {
      return const {};
    }
  }

  Future<bool> hasSession(SshConnection connection, String name) async {
    final builder = TmuxCommandBuilder(
      quoter: _quoterFor(connection.host.platform),
    );
    final result = await connection.run(builder.hasSession(name));
    return result.exitCode == 0;
  }

  Future<void> renameSession(
    SshConnection connection,
    String from,
    String to,
  ) async {
    final builder = TmuxCommandBuilder(
      quoter: _quoterFor(connection.host.platform),
    );
    final result = await connection.run(builder.renameSession(from, to));
    if (!result.succeeded) {
      throw TmuxOperationException(
        'Could not rename the session.',
        detail: result.combined.trim(),
      );
    }
  }

  Future<void> killSession(SshConnection connection, String name) async {
    final builder = TmuxCommandBuilder(
      quoter: _quoterFor(connection.host.platform),
    );
    final result = await connection.run(builder.killSession(name));
    if (!result.succeeded) {
      throw TmuxOperationException(
        'Could not end the session.',
        detail: result.combined.trim(),
      );
    }
  }

  static ShellQuoter _quoterFor(RemotePlatform platform) =>
      ShellQuoter.forPlatform(platform);
}

/// Raised when a tmux management command fails on the remote side.
class TmuxOperationException implements Exception {
  const TmuxOperationException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => message;
}
