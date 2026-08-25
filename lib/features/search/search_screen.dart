import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../shared/navigation/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';
import '../commands/command_runner.dart';
import '../sessions/session_actions.dart';

/// One app-wide search over local metadata (SPEC 20).
///
/// Searches only what is saved on this device. Crawling remote filesystems is
/// explicitly out of scope, and saying so on screen prevents the reasonable
/// assumption that a blank result means the file is not there.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<Host> _hosts = const [];
  List<Project> _projects = const [];
  List<SavedCommand> _commands = const [];
  List<SessionRecord> _sessions = const [];
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Debounced so each keystroke does not fire five queries.
  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _hosts = const [];
        _projects = const [];
        _commands = const [];
        _sessions = const [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () => _run(query));
  }

  Future<void> _run(String query) async {
    final results = await Future.wait([
      ref.read(hostsRepositoryProvider).search(query),
      ref.read(projectsRepositoryProvider).search(query),
      ref.read(commandsRepositoryProvider).search(query),
      ref.read(sessionsRepositoryProvider).search(query),
    ]);

    if (!mounted) return;
    setState(() {
      _hosts = results[0] as List<Host>;
      _projects = results[1] as List<Project>;
      _commands = results[2] as List<SavedCommand>;
      _sessions = results[3] as List<SessionRecord>;
      _searched = true;
    });
  }

  bool get _hasResults =>
      _hosts.isNotEmpty ||
      _projects.isNotEmpty ||
      _commands.isNotEmpty ||
      _sessions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.searchLocalOnly,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: !_searched
                ? const SizedBox.shrink()
                : !_hasResults
                ? EmptyState(
                    icon: Icons.search_off,
                    title: l10n.searchEmpty,
                    body: l10n.searchLocalOnly,
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      if (_hosts.isNotEmpty) ...[
                        SectionHeader(title: l10n.searchSectionComputers),
                        for (final host in _hosts)
                          ListTile(
                            leading: const Icon(Icons.computer_outlined),
                            title: Text(host.name),
                            subtitle: Text(host.displaySubtitle),
                            onTap: () => context.go(Routes.hostDetail(host.id)),
                          ),
                      ],
                      if (_projects.isNotEmpty) ...[
                        SectionHeader(title: l10n.searchSectionProjects),
                        for (final project in _projects)
                          ListTile(
                            leading: const Icon(Icons.folder_special_outlined),
                            title: Text(project.name),
                            subtitle: Text(
                              shortenPath(project.remotePath),
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            onTap: () =>
                                context.go(Routes.projectDetail(project.id)),
                          ),
                      ],
                      if (_commands.isNotEmpty) ...[
                        SectionHeader(title: l10n.searchSectionCommands),
                        for (final command in _commands)
                          ListTile(
                            leading: Icon(
                              command.isInteractive
                                  ? Icons.terminal
                                  : Icons.play_arrow_outlined,
                            ),
                            title: Text(command.name),
                            subtitle: Text(
                              command.command,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            onTap: () => runSavedCommand(context, ref, command),
                          ),
                      ],
                      if (_sessions.isNotEmpty) ...[
                        SectionHeader(title: l10n.searchSectionSessions),
                        for (final session in _sessions)
                          ListTile(
                            leading: Icon(
                              session.isPersistent
                                  ? Icons.play_circle_outline
                                  : Icons.terminal,
                            ),
                            title: Text(session.displayName),
                            subtitle: Text(
                              formatRelativeTime(l10n, session.lastUsedAt),
                            ),
                            onTap: () =>
                                resumeSessionRecord(context, ref, session),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
