import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/sessions_repository.dart';
import '../../core/shell/session_launch.dart';
import '../../core/shell/tmux.dart';
import '../../core/ssh/connection_manager.dart';
import '../../core/ssh/tmux_service.dart';
import '../../shared/models/models.dart';
import 'terminal_session.dart';

/// Holds every open terminal and which one is in front (SPEC 10.6).
///
/// Tabs are capped, and the cap is a real product decision: each open terminal
/// holds a scrollback buffer and an SSH channel, and a phone that has quietly
/// accumulated twenty of them will stutter. Closing the oldest idle tab is
/// better than degrading every tab.
class TerminalManager extends ChangeNotifier {
  TerminalManager({
    required this.connections,
    required this.sessions,
    required this.tmux,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final ConnectionManager connections;
  final SessionsRepository sessions;
  final TmuxService tmux;
  final Uuid _uuid;

  /// Beyond this, opening a new terminal closes the least recently used one
  /// that is not currently attached.
  static const int maxTabs = 8;

  final List<TerminalSession> _tabs = [];
  final Map<String, DateTime> _lastFocused = {};

  String? _activeId;

  List<TerminalSession> get tabs => List.unmodifiable(_tabs);

  bool get isEmpty => _tabs.isEmpty;

  int get length => _tabs.length;

  TerminalSession? get active {
    final id = _activeId;
    if (id == null) return null;
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  TerminalSession? byId(String id) {
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  /// An open terminal already attached to [tmuxSessionName] on [hostId].
  ///
  /// Resuming a session that is already on screen should focus that tab rather
  /// than opening a second client onto the same tmux session, which would make
  /// both windows fight over the terminal size.
  TerminalSession? findAttached({
    required String hostId,
    required String tmuxSessionName,
  }) {
    for (final tab in _tabs) {
      if (tab.host.id == hostId &&
          tab.tmuxSessionName == tmuxSessionName &&
          tab.isLive) {
        return tab;
      }
    }
    return null;
  }

  void setActive(String id) {
    if (_activeId == id) return;
    _activeId = id;
    _lastFocused[id] = DateTime.now();
    notifyListeners();
  }

  /// Opens a terminal and starts it.
  Future<TerminalSession> open({
    required Host host,
    required SessionLaunchPlan plan,
    required AppPreferences preferences,
    Project? project,
    String? title,
    String? sessionRecordId,
  }) async {
    await _enforceTabLimit();

    final session = TerminalSession(
      id: _uuid.v4(),
      host: host,
      project: project,
      launchPlan: plan,
      preferences: preferences,
      connections: connections,
      sessionRecordId: sessionRecordId,
      title: title,
    );

    session.addListener(notifyListeners);
    _tabs.add(session);
    _activeId = session.id;
    _lastFocused[session.id] = DateTime.now();
    notifyListeners();

    await session.start();

    // The record is written after a successful start so the Continue list never
    // offers a session that never existed.
    if (session.isLive) {
      await _recordSession(session);
    }
    return session;
  }

  Future<void> _recordSession(TerminalSession session) async {
    final existingId = session.sessionRecordId;
    if (existingId != null) {
      await sessions.touch(existingId);
      return;
    }

    final tmuxName = session.tmuxSessionName;
    if (tmuxName != null) {
      final existing = await sessions.byTmuxName(
        hostId: session.host.id,
        tmuxSessionName: tmuxName,
      );
      if (existing != null) {
        await sessions.touch(existing.id);
        return;
      }
    }

    final now = DateTime.now();
    await sessions.upsert(
      SessionRecord(
        id: _uuid.v4(),
        hostId: session.host.id,
        projectId: session.project?.id,
        tmuxSessionName: tmuxName,
        displayName: session.title,
        mode: session.launchPlan.mode,
        workingDirectory: session.launchPlan.workingDirectory,
        createdAt: now,
        lastUsedAt: now,
      ),
    );
  }

  /// Generates a managed tmux name that does not collide, checking both what
  /// this device remembers and what the host actually reports.
  Future<String> managedNameFor({
    required Host host,
    required String subject,
    required String prefix,
    String? action,
  }) async {
    final known = await sessions.tmuxNamesForHost(host.id);
    final connection = connections.connectionFor(host.id);
    if (connection != null && connection.isConnected) {
      known.addAll(await tmux.sessionNames(connection));
    }
    return TmuxCommandBuilder.managedSessionName(
      prefix: prefix,
      subject: subject,
      action: action,
      existingNames: known,
    );
  }

  /// Closes the least recently focused closable tab once the cap is reached.
  Future<void> _enforceTabLimit() async {
    if (_tabs.length < maxTabs) return;

    final candidates = _tabs.where((tab) => tab.id != _activeId).toList()
      ..sort((a, b) {
        final aTime = _lastFocused[a.id] ?? DateTime(1970);
        final bTime = _lastFocused[b.id] ?? DateTime(1970);
        return aTime.compareTo(bTime);
      });

    if (candidates.isEmpty) return;
    await close(candidates.first.id);
  }

  Future<void> close(String id) async {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;

    final session = _tabs.removeAt(index);
    _lastFocused.remove(id);
    session.removeListener(notifyListeners);
    await session.close();
    session.dispose();

    if (_activeId == id) {
      _activeId = _tabs.isEmpty
          ? null
          : _tabs[index.clamp(0, _tabs.length - 1)].id;
    }
    notifyListeners();
  }

  /// Closes every terminal for a host, e.g. when the host is deleted.
  Future<void> closeForHost(String hostId) async {
    final ids = _tabs
        .where((tab) => tab.host.id == hostId)
        .map((tab) => tab.id)
        .toList();
    for (final id in ids) {
      await close(id);
    }
  }

  Future<void> closeAll() async {
    final ids = _tabs.map((tab) => tab.id).toList();
    for (final id in ids) {
      await close(id);
    }
  }

  /// After returning to the foreground, marks terminals whose transport died
  /// while the app was away (SPEC 28).
  void reviewAfterForeground() {
    connections.reviewAfterForeground();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.removeListener(notifyListeners);
      tab.dispose();
    }
    _tabs.clear();
    super.dispose();
  }
}
