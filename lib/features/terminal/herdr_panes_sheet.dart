import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/shell/multiplexer.dart';
import '../../core/ssh/herdr_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../sessions/session_actions.dart';

Future<void> showHerdrPanes(
  BuildContext context,
  WidgetRef ref,
  Host host, {
  Project? project,
}) async {
  final selection = await showModalBottomSheet<(String, HerdrPane)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        FractionallySizedBox(heightFactor: .85, child: _HerdrPanes(host: host)),
  );
  if (selection == null || !context.mounted) return;
  await openHerdrPane(
    context,
    ref,
    host,
    selection.$1,
    selection.$2,
    project: project,
  );
}

class _HerdrPanes extends ConsumerStatefulWidget {
  const _HerdrPanes({required this.host});
  final Host host;
  @override
  ConsumerState<_HerdrPanes> createState() => _HerdrPanesState();
}

class _HerdrPanesState extends ConsumerState<_HerdrPanes> {
  List<String> _sessions = [];
  List<HerdrPane> _panes = [];
  String? _selected;
  Object? _error;
  bool _loading = true;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? session}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connection = await ref
          .read(appServicesProvider)
          .connections
          .connect(widget.host);
      var sessions = _sessions;
      if (session == null) {
        final result = await connection.run(
          const HerdrMultiplexer().listSessions(),
        );
        if (!result.succeeded) throw StateError(result.combined);
        sessions = const HerdrMultiplexer()
            .parseSessions(result.stdout)
            .map((s) => s.name)
            .toList();
      }
      final selected =
          session ??
          (sessions.contains(_selected) ? _selected : sessions.firstOrNull);
      final panes = selected == null
          ? <HerdrPane>[]
          : await const HerdrService().panes(connection, selected);
      if (!mounted || request != _request) return;
      setState(() {
        _sessions = sessions;
        _selected = selected;
        _panes = panes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.herdrPanes,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : () => _load(),
                  tooltip: l10n.actionRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (_sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _selected,
                key: ValueKey(_selected),
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.herdrSession),
                items: _sessions
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value != null) _load(session: value);
                      },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Text('${l10n.herdrUnavailable}\n\n$_error'),
                  )
                : _panes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.herdrEmpty),
                    ),
                  )
                : ListView.builder(
                    itemCount: _panes.length,
                    itemBuilder: (context, index) {
                      final pane = _panes[index];
                      return ListTile(
                        leading: Icon(
                          pane.agent == null
                              ? Icons.terminal
                              : Icons.chat_bubble_outline,
                        ),
                        title: Text(pane.title),
                        subtitle: Text(
                          '${pane.id} · ${pane.status}\n${pane.directory ?? ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, (_selected!, pane)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
