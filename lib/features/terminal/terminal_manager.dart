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

/// Raised instead of silently terminating a live shell when every terminal
/// slot is in use. The user can explicitly close the tab whose work is done.
class TerminalTabLimitException implements Exception {
  const TerminalTabLimitException();

  @override
  String toString() =>
      'All $maxTabs terminal tabs are active. Close a terminal before opening another.';

  static const int maxTabs = TerminalManager.maxTabs;
}

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

  /// Beyond this, opening a new terminal may close an inactive tab only.
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
  /// both windows fight over the terminal size. A disconnected tab still owns
  /// the attachment and is returned so the caller can reconnect it.
  TerminalSession? findAttached({
    required String hostId,
    required String tmuxSessionName,
  }) {
    for (final tab in _tabs) {
      if (tab.host.id == hostId && tab.tmuxSessionName == tmuxSessionName) {
        return tab;
      }
    }
    return null;
  }

  /// An open tab that would run the same plan in the same context.
  ///
  /// Connect uses this to focus its existing terminal or retry an interrupted
  /// one instead of quietly opening another shell. Callers that intentionally
  /// need another terminal bypass this lookup and call [open] directly.
  TerminalSession? findMatching({
    required String hostId,
    String? projectId,
    required SessionLaunchPlan plan,
  }) {
    for (final tab in _tabs) {
      final openedPlan = tab.launchPlan;
      if (tab.host.id != hostId ||
          tab.project?.id != projectId ||
          openedPlan.mode != plan.mode ||
          openedPlan.shellCommand != plan.shellCommand ||
          openedPlan.initialInput != plan.initialInput ||
          openedPlan.tmuxSessionName != plan.tmuxSessionName ||
          openedPlan.workingDirectory != plan.workingDirectory) {
        continue;
      }
      return tab;
    }
    return null;
  }

  void setActive(String id) {
    if (_activeId == id) return;
    _activeId = id;
    _lastFocused[id] = DateTime.now();
    notifyListeners();
  }

  /// Moves to the adjacent open terminal, wrapping at either end.
  ///
  /// Returning the selected terminal lets a UI update its route without
  /// exposing the tab-ordering details that make the switch safe.
  TerminalSession? moveActive({required bool forward}) {
    if (_tabs.length < 2) return null;
    final activeId = _activeId;
    if (activeId == null) return null;
    final currentIndex = _tabs.indexWhere((tab) => tab.id == activeId);
    if (currentIndex < 0) return null;

    final nextIndex = (currentIndex + (forward ? 1 : -1)) % _tabs.length;
    final wrappedIndex = nextIndex < 0 ? nextIndex + _tabs.length : nextIndex;
    final next = _tabs[wrappedIndex];
    setActive(next.id);
    return next;
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
    // Avoid yielding before this tab is registered. A second Connect press
    // must be able to find the tab while its SSH connection is starting.
    if (_tabs.length >= maxTabs) {
      await _enforceTabLimit();
    }

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
    final now = DateTime.now();
    final record = SessionRecord(
      id: _uuid.v4(),
      hostId: session.host.id,
      projectId: session.project?.id,
      tmuxSessionName: tmuxName,
      displayName: session.title,
      mode: session.launchPlan.mode,
      workingDirectory: session.launchPlan.workingDirectory,
      createdAt: now,
      lastUsedAt: now,
    );

    if (tmuxName == null) {
      await sessions.upsertDirectTarget(record);
      return;
    }

    final existing = await sessions.byTmuxName(
      hostId: session.host.id,
      tmuxSessionName: tmuxName,
    );
    if (existing != null) {
      await sessions.touch(existing.id);
      return;
    }
    await sessions.upsert(record);
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

  /// Closes the least recently focused inactive tab once the cap is reached.
  ///
  /// A direct terminal can hold an irreversible foreground process, so a live
  /// tab is never an eviction candidate. If every tab is live, the caller gets
  /// an explicit error rather than losing remote work without consent.
  Future<void> _enforceTabLimit() async {
    if (_tabs.length < maxTabs) return;

    final candidates =
        _tabs.where((tab) => tab.id != _activeId && !tab.isLive).toList()
          ..sort((a, b) {
            final aTime = _lastFocused[a.id] ?? DateTime(1970);
            final bTime = _lastFocused[b.id] ?? DateTime(1970);
            return aTime.compareTo(bTime);
          });

    if (candidates.isEmpty) throw const TerminalTabLimitException();
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
