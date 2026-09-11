import '../../shared/models/models.dart';
import '../shell/multiplexer.dart';
import '../shell/multiplexer_session.dart';
import 'ssh_connection.dart';

/// Whether a remote machine can host persistent sessions.
class MultiplexerAvailability {
  const MultiplexerAvailability({
    required this.available,
    this.version,
    this.reason,
  });

  const MultiplexerAvailability.unavailable(this.reason)
    : available = false,
      version = null;

  final bool available;

  /// e.g. `tmux 3.4` or `herdr 0.8.0`.
  final String? version;

  /// Why persistent sessions cannot be used, when [available] is false.
  final String? reason;
}

/// Discovers and manages multiplexer sessions on a connected host (SPEC 11).
///
/// Everything here is read-or-attach. The app never installs a multiplexer and
/// never kills a session the user did not explicitly ask to kill (SPEC 11.4).
/// The one exception is the tmux `mouse on` / `history-limit` prelude in
/// [TmuxCommandBuilder.sessionSetup], which the app does set because without it
/// a persistent session cannot be scrolled from a phone at all.
class MultiplexerService {
  const MultiplexerService();

  /// The backend configured for [host].
  Multiplexer backendFor(Host host) =>
      Multiplexer.forPlatform(host.multiplexer, host.platform);

  /// Checks whether the host's multiplexer exists on the far side.
  ///
  /// Windows hosts short-circuit: emitting `command -v tmux` at a PowerShell
  /// prompt produces a confusing error rather than a useful answer.
  Future<MultiplexerAvailability> detect(SshConnection connection) async {
    final host = connection.host;
    if (!host.platform.supportsMultiplexer) {
      return const MultiplexerAvailability.unavailable(
        'Persistent sessions need a terminal multiplexer, which is not '
        'available on Windows computers.',
      );
    }

    final backend = backendFor(host);
    final result = await connection.run(backend.detect());
    final output = result.combined.trim();

    if (output.isEmpty || output.contains(Multiplexer.missingSentinel)) {
      return MultiplexerAvailability.unavailable(
        '${backend.kind.label} is not installed on this computer.',
      );
    }
    return MultiplexerAvailability(
      available: true,
      version: output.split('\n').first.trim(),
    );
  }

  /// Lists the sessions currently running on the host.
  ///
  /// Returns an empty list when the multiplexer is present but has no sessions,
  /// and throws [MultiplexerUnavailableException] when it is missing, so callers
  /// can tell the two apart and offer a direct terminal instead (SPEC 11.4).
  Future<List<MultiplexerSession>> listSessions(
    SshConnection connection,
  ) async {
    final host = connection.host;
    if (!host.platform.supportsMultiplexer) {
      throw MultiplexerUnavailableException(host.multiplexer);
    }

    final backend = backendFor(host);
    final result = await connection.run(backend.listSessions());

    if (result.exitCode == 127) {
      throw MultiplexerUnavailableException(backend.kind);
    }

    return backend.parseSessions(result.stdout);
  }

  /// Session names in use, for collision-free name generation.
  Future<Set<String>> sessionNames(SshConnection connection) async {
    try {
      final sessions = await listSessions(connection);
      return sessions.map((session) => session.name).toSet();
    } on MultiplexerUnavailableException {
      return const {};
    }
  }

  Future<bool> hasSession(SshConnection connection, String name) async {
    final result = await connection.run(
      backendFor(connection.host).hasSession(name),
    );
    return result.exitCode == 0;
  }

  /// Whether the host's backend can rename a live session.
  ///
  /// Herdr cannot, so the UI hides the action rather than offering something
  /// that would fail on the far side.
  bool supportsRename(Host host) => backendFor(host).supportsRename;

  Future<void> renameSession(
    SshConnection connection,
    String from,
    String to,
  ) async {
    final backend = backendFor(connection.host);
    if (!backend.supportsRename) {
      throw MultiplexerOperationException(
        '${backend.kind.label} cannot rename a running session.',
      );
    }
    final result = await connection.run(backend.renameSession(from, to));
    if (!result.succeeded) {
      throw MultiplexerOperationException(
        'Could not rename the session.',
        detail: result.combined.trim(),
      );
    }
  }

  Future<void> killSession(SshConnection connection, String name) async {
    final result = await connection.run(
      backendFor(connection.host).killSession(name),
    );
    if (!result.succeeded) {
      throw MultiplexerOperationException(
        'Could not end the session.',
        detail: result.combined.trim(),
      );
    }
  }
}
