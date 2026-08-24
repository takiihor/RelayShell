import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/models.dart';
import '../database/hosts_repository.dart';
import 'credential_resolver.dart';
import 'host_key_verifier.dart';
import 'ssh_connection.dart';
import 'ssh_failure.dart';

/// Owns every live [SshConnection] and coordinates reconnection (SPEC 9.4, 28).
///
/// One connection is kept per host and shared by all its terminals, file
/// browsers and forwards. Multiplexing channels over a single transport is what
/// makes opening a second terminal instant instead of a fresh handshake, and it
/// keeps a phone from holding several sockets open per machine.
class ConnectionManager {
  ConnectionManager({
    required this.hosts,
    required this.credentials,
    required this.verifier,
    required this.preferences,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final HostsRepository hosts;
  final CredentialResolver credentials;
  final HostKeyVerifier verifier;
  final Uuid _uuid;

  /// Settings applied to connections opened from now on.
  AppPreferences preferences;

  final Map<String, SshConnection> _connections = {};
  final Map<String, Future<SshConnection>> _pending = {};
  final Map<String, Timer> _reconnectTimers = {};

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Emits whenever a connection is added, removed or changes state.
  Stream<void> get changes => _changes.stream;

  /// Connections currently held, live or failed.
  List<SshConnection> get connections => List.unmodifiable(_connections.values);

  SshConnection? connectionFor(String hostId) => _connections[hostId];

  bool isConnected(String hostId) => _connections[hostId]?.isConnected ?? false;

  /// Applies new settings to connections opened from now on.
  ///
  /// Existing connections keep the settings they were created with; changing a
  /// keepalive interval mid-session would mean tearing down a working
  /// connection to apply it, which is worse than waiting for the next one.
  void updatePreferences(AppPreferences next) {
    preferences = next;
  }

  /// Returns a connected [SshConnection] for [host], opening one if needed.
  ///
  /// Concurrent callers share one attempt: two terminals opened at once must
  /// not produce two handshakes, two fingerprint prompts and two passphrase
  /// dialogs.
  Future<SshConnection> connect(Host host) {
    final existing = _connections[host.id];
    if (existing != null && existing.isConnected) {
      return Future.value(existing);
    }

    final pending = _pending[host.id];
    if (pending != null) return pending;

    final attempt = _openConnection(host);
    _pending[host.id] = attempt;
    return attempt.whenComplete(() => _pending.remove(host.id));
  }

  Future<SshConnection> _openConnection(Host host) async {
    _cancelReconnect(host.id);
    await _connections.remove(host.id)?.dispose();

    final connection = SshConnection(
      id: _uuid.v4(),
      host: host,
      credentials: credentials,
      verifier: verifier,
      preferences: preferences,
    );
    _connections[host.id] = connection;
    _notify();

    connection.statusStream.listen(
      (status) {
        _notify();
        if (status.state == SshConnectionState.failed &&
            status.failure != null) {
          _considerAutoReconnect(host, status);
        }
      },
      onError: (_) => _notify(),
    );

    try {
      await connection.connect();
      await hosts.markConnected(host.id);
      return connection;
    } on SshFailure {
      rethrow;
    }
  }

  /// Reconnects [host] explicitly, at the user's request.
  Future<SshConnection> reconnect(Host host) {
    _cancelReconnect(host.id);
    return connect(host);
  }

  /// Schedules a bounded automatic retry (SPEC 9.4).
  ///
  /// Only transport-level failures retry. A wrong password or a changed host
  /// key will fail identically every time, and retrying would just replay the
  /// user's prompts. Retries stop after [AppPreferences.maxReconnectAttempts];
  /// there is no infinite loop.
  void _considerAutoReconnect(Host host, SshConnectionStatus status) {
    final failure = status.failure;
    if (failure == null || !failure.isRetryable) return;

    switch (preferences.reconnectBehavior) {
      case ReconnectBehavior.ask:
        return;
      case ReconnectBehavior.autoOnce:
        if (status.reconnectAttempt >= 1) return;
      case ReconnectBehavior.autoBounded:
        if (status.reconnectAttempt >= preferences.maxReconnectAttempts) return;
    }

    if (_reconnectTimers.containsKey(host.id)) return;

    final nextAttempt = status.reconnectAttempt + 1;
    final delay = _backoffFor(nextAttempt);

    _reconnectTimers[host.id] = Timer(delay, () async {
      _reconnectTimers.remove(host.id);
      final connection = _connections[host.id];
      if (connection == null || connection.isConnected) return;
      try {
        await connection.connect(reconnectAttempt: nextAttempt);
        await hosts.markConnected(host.id);
      } on SshFailure {
        // The status stream already carries the failure; the attempt counter
        // in it is what stops this from repeating forever.
      }
    });
  }

  /// Exponential backoff, capped so a long outage does not stretch retries out
  /// past the point of usefulness.
  static Duration _backoffFor(int attempt) {
    final seconds = (1 << (attempt - 1)).clamp(1, 30);
    return Duration(seconds: seconds);
  }

  void _cancelReconnect(String hostId) {
    _reconnectTimers.remove(hostId)?.cancel();
  }

  Future<void> disconnect(String hostId) async {
    _cancelReconnect(hostId);
    final connection = _connections.remove(hostId);
    await connection?.dispose();
    _notify();
  }

  Future<void> disconnectAll() async {
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    final all = _connections.values.toList();
    _connections.clear();
    for (final connection in all) {
      await connection.dispose();
    }
    _notify();
  }

  /// Re-checks every connection after the app returns to the foreground
  /// (SPEC 28).
  ///
  /// The OS may have torn down sockets while backgrounded without the transport
  /// noticing, so a stale-but-"connected" entry is dropped rather than handed
  /// to a terminal that would then hang.
  void reviewAfterForeground() {
    for (final entry in _connections.entries.toList()) {
      final connection = entry.value;
      if (connection.status.state == SshConnectionState.connected &&
          !connection.isConnected) {
        unawaited(disconnect(entry.key));
      }
    }
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await disconnectAll();
    await _changes.close();
  }
}

/// Advisory reachability probing for the Home screen (SPEC 7.2).
///
/// Deliberately minimal: a bounded number of checks, started only for hosts the
/// user can actually see, and never on a timer. A failed probe never blocks a
/// connection attempt — the app must always let the user try.
class ReachabilityProbe {
  ReachabilityProbe({this.maxConcurrent = 3});

  /// Home must not fan out dozens of simultaneous checks (SPEC 36).
  final int maxConcurrent;

  final Map<String, HostReachability> _results = {};
  final Set<String> _inFlight = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  HostReachability statusFor(String hostId) =>
      _results[hostId] ?? HostReachability.unknown;

  /// Probes [host] unless a probe is already running or the queue is full.
  Future<void> probe(
    Host host, {
    required Future<bool> Function(String hostname, int port) check,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_inFlight.contains(host.id) || _inFlight.length >= maxConcurrent) return;

    _inFlight.add(host.id);
    _results[host.id] = HostReachability.checking;
    _emit();

    try {
      final reachable = await check(host.hostname, host.port).timeout(timeout);
      _results[host.id] =
          reachable ? HostReachability.reachable : HostReachability.unreachable;
    } catch (_) {
      _results[host.id] = HostReachability.unreachable;
    } finally {
      _inFlight.remove(host.id);
      _emit();
    }
  }

  void markReachable(String hostId) {
    _results[hostId] = HostReachability.reachable;
    _emit();
  }

  void clear() {
    _results.clear();
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

/// Opens and immediately closes a TCP socket, to answer "is SSH listening?".
@visibleForTesting
typedef ReachabilityCheck = Future<bool> Function(String hostname, int port);
