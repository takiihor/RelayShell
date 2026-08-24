import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../../shared/models/models.dart';
import 'credential_resolver.dart';
import 'host_key_verifier.dart';
import 'ssh_failure.dart';

/// Observable state of one SSH connection (SPEC 9.1).
@immutable
class SshConnectionStatus {
  const SshConnectionStatus({
    required this.state,
    this.failure,
    this.reconnectAttempt = 0,
    this.banner,
  });

  final SshConnectionState state;
  final SshFailure? failure;

  /// How many automatic reconnects have been tried, for bounded backoff.
  final int reconnectAttempt;

  /// Server-supplied login banner, if any.
  final String? banner;

  SshConnectionStatus copyWith({
    SshConnectionState? state,
    SshFailure? failure,
    int? reconnectAttempt,
    String? banner,
  }) =>
      SshConnectionStatus(
        state: state ?? this.state,
        failure: failure ?? this.failure,
        reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
        banner: banner ?? this.banner,
      );
}

/// One live SSH connection to a [Host] (SPEC 27).
///
/// Owns the socket, the transport, host verification, authentication and
/// keepalive, and exposes only domain operations so no dartssh2 type leaks into
/// the UI layer. Channels opened from this connection (shells, exec, SFTP,
/// forwards) share its lifetime.
class SshConnection {
  SshConnection({
    required this.id,
    required this.host,
    required this.credentials,
    required this.verifier,
    required this.preferences,
  });

  /// Stable identifier for this connection instance.
  final String id;

  final Host host;
  final CredentialResolver credentials;
  final HostKeyVerifier verifier;
  final AppPreferences preferences;

  SSHClient? _client;
  SftpClient? _sftp;

  final StreamController<SshConnectionStatus> _statusController =
      StreamController<SshConnectionStatus>.broadcast();

  SshConnectionStatus _status =
      const SshConnectionStatus(state: SshConnectionState.idle);

  /// Latest status. Also delivered to new listeners of [statusStream].
  SshConnectionStatus get status => _status;

  Stream<SshConnectionStatus> get statusStream async* {
    yield _status;
    yield* _statusController.stream;
  }

  bool get isConnected =>
      _client != null &&
      !_client!.isClosed &&
      _status.state == SshConnectionState.connected;

  /// Completes when the transport closes for any reason.
  Future<void> get done => _client?.done ?? Future<void>.value();

  void _setStatus(SshConnectionStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  void _setState(SshConnectionState state) =>
      _setStatus(SshConnectionStatus(state: state, banner: _status.banner));

  /// Establishes the connection, running through the full SPEC 9.1 state
  /// machine so the UI can narrate progress.
  ///
  /// Throws [SshFailure] on any failure; the status stream ends at
  /// [SshConnectionState.failed] with the same failure attached.
  Future<void> connect({int reconnectAttempt = 0}) async {
    if (isConnected) return;

    _setStatus(
      SshConnectionStatus(
        state: reconnectAttempt > 0
            ? SshConnectionState.reconnecting
            : SshConnectionState.resolving,
        reconnectAttempt: reconnectAttempt,
      ),
    );

    SSHSocket? socket;
    try {
      // Credentials are resolved before the socket opens so that a cancelled
      // biometric or passphrase prompt costs nothing on the network.
      final credential = await credentials.resolve(host);

      _setState(SshConnectionState.connecting);
      socket = await SSHSocket.connect(
        host.hostname,
        host.port,
        timeout: preferences.connectTimeout,
      );

      _setState(SshConnectionState.handshaking);

      final client = SSHClient(
        socket,
        username: host.username,
        identities: credential.identities,
        onPasswordRequest: credential.password == null
            ? null
            : () => credential.password!.expose(),
        onUserInfoRequest: credential.onUserInfoRequest,
        onUserauthBanner: (banner) =>
            _setStatus(_status.copyWith(banner: banner)),
        onVerifyHostKey: (type, fingerprint) async {
          _setState(SshConnectionState.verifyingHost);
          final trusted = await verifier.callbackFor(host)(type, fingerprint);
          if (trusted) _setState(SshConnectionState.authenticating);
          return trusted;
        },
        keepAliveInterval: preferences.keepalive,
        // No handshakeTimeout: dartssh2 starts this timer at construction and
        // only cancels it once authentication begins, so it silently covers
        // the host-key trust prompt above. That prompt is a human decision
        // with no deadline by design (SPEC 9.2) — a user reading a fingerprint
        // must never have the connection die under them mid-read. Socket
        // reachability is already bounded by the `timeout:` on
        // SSHSocket.connect above; authTimeout below bounds the phase after
        // the user has already decided, which has no human step to wait on.
        authTimeout: preferences.authTimeout,
        ident: 'RelayShell_1.0',
      );

      _client = client;
      unawaited(_watchForClose(client));

      await client.authenticated;
      _setStatus(
        SshConnectionStatus(
          state: SshConnectionState.connected,
          banner: _status.banner,
        ),
      );
    } catch (error) {
      socket?.destroy();
      _client = null;

      // A rejected or changed host key produces a generic transport error from
      // the library; the verifier knows the real reason.
      final failure = verifier.lastFailure ??
          SshFailure.from(error, hostname: host.hostname, port: host.port);

      _setStatus(
        SshConnectionStatus(
          state: SshConnectionState.failed,
          failure: failure,
          reconnectAttempt: reconnectAttempt,
        ),
      );
      throw failure;
    }
  }

  Future<void> _watchForClose(SSHClient client) async {
    try {
      await client.done;
    } catch (_) {
      // The failure is reported through the status below.
    }
    if (_client != client) return;
    _sftp = null;
    _client = null;
    if (_status.state == SshConnectionState.closed ||
        _status.state == SshConnectionState.failed) {
      return;
    }
    _setStatus(
      SshConnectionStatus(
        state: SshConnectionState.failed,
        failure: const SshFailure(
          kind: SshFailureKind.connectionLost,
          message: 'Connection lost.',
          action: 'Reconnect to continue.',
        ),
      ),
    );
  }

  SSHClient _requireClient() {
    final client = _client;
    if (client == null || client.isClosed) {
      throw const SshFailure(
        kind: SshFailureKind.connectionLost,
        message: 'Not connected.',
        action: 'Reconnect to continue.',
      );
    }
    return client;
  }

  /// Opens an interactive shell with a PTY.
  Future<SSHSession> openShell({
    required int columns,
    required int rows,
    String? terminalType,
    Map<String, String>? environment,
  }) async {
    final client = _requireClient();
    try {
      return await client.shell(
        pty: SSHPtyConfig(
          type: terminalType ?? preferences.terminalType,
          width: columns,
          height: rows,
        ),
        environment: environment,
      );
    } catch (error) {
      throw SshFailure.from(error, hostname: host.hostname, port: host.port);
    }
  }

  /// Runs [command] in its own session, optionally with a PTY.
  ///
  /// A PTY is needed for commands that behave differently when not attached to
  /// a terminal; one-shot commands normally run without one so their output is
  /// clean.
  Future<SSHSession> execute(
    String command, {
    bool pty = false,
    int columns = 120,
    int rows = 40,
  }) async {
    final client = _requireClient();
    try {
      return await client.execute(
        command,
        pty: pty
            ? SSHPtyConfig(
                type: preferences.terminalType,
                width: columns,
                height: rows,
              )
            : null,
      );
    } catch (error) {
      throw SshFailure.from(error, hostname: host.hostname, port: host.port);
    }
  }

  /// Runs [command] and collects its output.
  ///
  /// Intended for the app's own small probes (tmux discovery, `pwd`) and for
  /// one-shot saved commands, all of which produce bounded output.
  Future<CommandResult> run(String command) async {
    final session = await execute(command);
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutDone = session.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach(stdoutBuffer.write);
    final stderrDone = session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach(stderrBuffer.write);

    await Future.wait([stdoutDone, stderrDone]);
    await session.done;

    return CommandResult(
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
      exitCode: session.exitCode,
    );
  }

  /// Opens (and caches) an SFTP client on this connection.
  ///
  /// Cached because SFTP opens a channel and a subsystem handshake; the file
  /// browser navigates often and should not pay that per directory.
  Future<SftpClient> sftp() async {
    final existing = _sftp;
    if (existing != null) return existing;
    final client = _requireClient();
    try {
      final sftp = await client.sftp();
      _sftp = sftp;
      return sftp;
    } catch (error) {
      throw SshFailure.from(error, hostname: host.hostname, port: host.port);
    }
  }

  /// Opens a direct-tcpip channel to [remoteHost]:[remotePort].
  Future<SSHForwardChannel> forwardLocal(String remoteHost, int remotePort) async {
    final client = _requireClient();
    try {
      return await client.forwardLocal(remoteHost, remotePort);
    } catch (error) {
      throw SshFailure.from(error, hostname: host.hostname, port: host.port);
    }
  }

  /// Asks the server to listen on [port] and forward connections back.
  Future<SSHRemoteForward?> forwardRemote({String? bindHost, int? port}) async {
    final client = _requireClient();
    try {
      return await client.forwardRemote(host: bindHost, port: port);
    } catch (error) {
      throw SshFailure.from(
        error,
        hostname: host.hostname,
        port: host.port,
      );
    }
  }

  /// Starts a local SOCKS5 proxy tunnelled through this connection.
  Future<SSHDynamicForward> forwardDynamic({
    String bindHost = '127.0.0.1',
    int? bindPort,
  }) async {
    final client = _requireClient();
    try {
      return await client.forwardDynamic(
        bindHost: bindHost,
        bindPort: bindPort,
      );
    } catch (error) {
      throw SshFailure.from(error, hostname: host.hostname, port: host.port);
    }
  }

  /// Closes the connection and everything opened from it.
  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    _sftp = null;
    _setState(SshConnectionState.closed);
    client?.close();
    if (client != null) {
      await client.done.catchError((_) {});
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
  }
}

/// Output of a completed one-shot command.
@immutable
class CommandResult {
  const CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int? exitCode;

  bool get succeeded => exitCode == 0;

  /// stdout when the command succeeded, otherwise whatever it wrote anywhere.
  String get combined {
    if (stderr.isEmpty) return stdout;
    if (stdout.isEmpty) return stderr;
    return '$stdout\n$stderr';
  }
}
