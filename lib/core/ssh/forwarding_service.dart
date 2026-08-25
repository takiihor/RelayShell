import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../shared/models/models.dart';
import 'ssh_connection.dart';
import 'ssh_failure.dart';

/// A forward that is currently running (SPEC 16).
class ActiveForward {
  ActiveForward._({
    required this.profile,
    required this.hostId,
    required this.boundPort,
    required Future<void> Function() stop,
    // ignore: prefer_initializing_formals
  }) : _stop = stop;

  final PortForwardProfile profile;
  final String hostId;

  /// The port actually opened. May differ from the requested port when the
  /// profile asked for port 0, or when the server assigned one.
  final int boundPort;

  final Future<void> Function() _stop;

  int _connectionCount = 0;

  /// How many connections have used this forward, for a useful status line.
  int get connectionCount => _connectionCount;

  bool _running = true;
  bool get isRunning => _running;

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _stop();
  }
}

/// Starts and stops SSH port forwards (SPEC 16).
///
/// Local and dynamic forwards open a real listening socket on the phone; the
/// SSH connection carries the traffic. Remote forwards ask the server to listen
/// and hand connections back. All three are stopped explicitly, and every one
/// dies with its SSH connection.
class ForwardingService {
  ForwardingService();

  final Map<String, ActiveForward> _active = {};
  final Map<String, StreamSubscription<SshConnectionStatus>>
  _connectionWatches = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  List<ActiveForward> get active => List.unmodifiable(_active.values);

  ActiveForward? forProfile(String profileId) => _active[profileId];

  bool isRunning(String profileId) => _active[profileId]?.isRunning ?? false;

  /// Starts [profile] over [connection].
  Future<ActiveForward> start(
    SshConnection connection,
    PortForwardProfile profile,
  ) async {
    final existing = _active[profile.id];
    if (existing != null && existing.isRunning) return existing;

    final forward = switch (profile.type) {
      ForwardType.local => await _startLocal(connection, profile),
      ForwardType.remote => await _startRemote(connection, profile),
      ForwardType.dynamicSocks => await _startDynamic(connection, profile),
    };

    _active[profile.id] = forward;
    _watchConnection(connection);
    _notify();
    return forward;
  }

  Future<ActiveForward> _startLocal(
    SshConnection connection,
    PortForwardProfile profile,
  ) async {
    final targetHost = profile.targetHost;
    final targetPort = profile.targetPort;
    if (targetHost == null || targetPort == null) {
      throw const SshFailure(
        kind: SshFailureKind.featureUnavailable,
        message: 'This local forward has no destination.',
        action: 'Set the remote host and port for this forward.',
      );
    }

    final ServerSocket server;
    try {
      server = await ServerSocket.bind(
        profile.listenAddress,
        profile.listenPort,
      );
    } on SocketException catch (error) {
      throw SshFailure(
        kind: SshFailureKind.featureUnavailable,
        message: 'Could not listen on port ${profile.listenPort}.',
        action: 'Another app may already be using that port.',
        technicalDetail: error.message,
      );
    }

    late final ActiveForward handle;

    final subscription = server.listen((socket) async {
      handle._connectionCount++;
      _notify();
      try {
        final channel = await connection.forwardLocal(targetHost, targetPort);
        // Pump both directions until either side closes.
        unawaited(
          socket.cast<List<int>>().pipe(channel.sink).catchError((_) {}),
        );
        unawaited(
          channel.stream.cast<List<int>>().pipe(socket).catchError((_) {}),
        );
      } catch (_) {
        // One failed connection must not take the listener down; the user
        // sees the failure in whatever app made the request.
        socket.destroy();
      }
    });

    handle = ActiveForward._(
      profile: profile,
      hostId: connection.host.id,
      boundPort: server.port,
      stop: () async {
        await subscription.cancel();
        await server.close();
      },
    );
    return handle;
  }

  Future<ActiveForward> _startRemote(
    SshConnection connection,
    PortForwardProfile profile,
  ) async {
    final targetHost = profile.targetHost;
    final targetPort = profile.targetPort;
    if (targetHost == null || targetPort == null) {
      throw const SshFailure(
        kind: SshFailureKind.featureUnavailable,
        message: 'This remote forward has no destination.',
        action: 'Set the local host and port for this forward.',
      );
    }

    final remote = await connection.forwardRemote(port: profile.listenPort);
    if (remote == null) {
      throw SshFailure(
        kind: SshFailureKind.featureUnavailable,
        message:
            'The computer refused to listen on port ${profile.listenPort}.',
        action:
            'The SSH server may have GatewayPorts disabled, or the port '
            'may be in use.',
      );
    }

    late final ActiveForward handle;

    final subscription = remote.connections.listen((channel) async {
      handle._connectionCount++;
      _notify();
      try {
        final socket = await Socket.connect(targetHost, targetPort);
        unawaited(
          channel.stream.cast<List<int>>().pipe(socket).catchError((_) {}),
        );
        unawaited(
          socket.cast<List<int>>().pipe(channel.sink).catchError((_) {}),
        );
      } catch (_) {
        await channel.close();
      }
    });

    handle = ActiveForward._(
      profile: profile,
      hostId: connection.host.id,
      boundPort: remote.port,
      stop: () async {
        await subscription.cancel();
        remote.close();
      },
    );
    return handle;
  }

  Future<ActiveForward> _startDynamic(
    SshConnection connection,
    PortForwardProfile profile,
  ) async {
    final dynamicForward = await connection.forwardDynamic(
      bindHost: profile.listenAddress,
      bindPort: profile.listenPort == 0 ? null : profile.listenPort,
    );

    return ActiveForward._(
      profile: profile,
      hostId: connection.host.id,
      boundPort: dynamicForward.port,
      stop: dynamicForward.close,
    );
  }

  Future<void> stop(String profileId) async {
    final forward = _active.remove(profileId);
    await forward?.stop();
    if (forward != null) _stopWatchingHostIfUnused(forward.hostId);
    _notify();
  }

  /// Stops every forward running over [hostId]'s connection.
  Future<void> stopForHost(String hostId) async {
    final ids = _active.entries
        .where((entry) => entry.value.hostId == hostId)
        .map((entry) => entry.key)
        .toList();
    for (final id in ids) {
      await stop(id);
    }
  }

  Future<void> stopAll() async {
    final all = _active.values.toList();
    _active.clear();
    for (final forward in all) {
      await forward.stop();
    }
    for (final subscription in _connectionWatches.values) {
      await subscription.cancel();
    }
    _connectionWatches.clear();
    _notify();
  }

  void _watchConnection(SshConnection connection) {
    if (_connectionWatches.containsKey(connection.host.id)) return;
    _connectionWatches[connection.host.id] = connection.statusStream.listen((
      status,
    ) {
      if (status.state == SshConnectionState.failed ||
          status.state == SshConnectionState.closed) {
        unawaited(stopForHost(connection.host.id));
      }
    }, onDone: () => unawaited(stopForHost(connection.host.id)));
  }

  void _stopWatchingHostIfUnused(String hostId) {
    if (_active.values.any((forward) => forward.hostId == hostId)) return;
    final subscription = _connectionWatches.remove(hostId);
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await stopAll();
    await _changes.close();
  }
}

/// Checks whether a local port can be bound, before saving a profile.
@visibleForTesting
Future<bool> isLocalPortAvailable(String address, int port) async {
  try {
    final socket = await ServerSocket.bind(address, port);
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}
