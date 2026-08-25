import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../core/shell/tmux.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../core/ssh/tmux_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';
import '../terminal/terminal_providers.dart';
import '../terminal/terminal_session.dart';
import 'session_actions.dart';

/// Saved and live sessions (SPEC 11.3).
///
/// Saved records are shown immediately from local metadata; the remote machine
/// is only asked what is actually running when the user requests it. That keeps
/// the screen instant offline and avoids connecting to every host on open
/// (SPEC 41).
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionRecordsProvider);
    final terminals = ref.watch(terminalManagerProvider);
    final hosts = ref.watch(hostsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.actionSearch,
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: sessions.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (records) {
          if (records.isEmpty && terminals.isEmpty) {
            return EmptyState(
              icon: Icons.dashboard_outlined,
              title: l10n.sessionsEmptyTitle,
              body: l10n.sessionsEmptyBody,
              actionLabel: hosts.isEmpty ? l10n.computersAdd : null,
              onAction: hosts.isEmpty
                  ? () => context.push(Routes.hostNew)
                  : null,
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (terminals.tabs.isNotEmpty) ...[
                SectionHeader(title: l10n.sessionsOpenTabs),
                for (final tab in terminals.tabs)
                  ListTile(
                    leading: const Icon(Icons.terminal),
                    title: Text(tab.title),
                    subtitle: Text(
                      '${_terminalStateLabel(l10n, tab.state)} · '
                      '${tab.subtitle}',
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        terminals.setActive(tab.id);
                        context.push('${Routes.terminal}?session=${tab.id}');
                      },
                      child: Text(l10n.actionOpen),
                    ),
                  ),
              ],
              if (records.isNotEmpty) ...[
                SectionHeader(title: l10n.sessionsSaved),
                for (final record in records) _SessionTile(record: record),
              ],
              for (final host in hosts.where(
                (host) => host.platform.supportsTmux,
              ))
                _HostTmuxSection(host: host),
            ],
          );
        },
      ),
    );
  }
}

String _terminalStateLabel(AppLocalizations l10n, TerminalSessionState state) =>
    switch (state) {
      TerminalSessionState.starting => l10n.terminalStateConnecting,
      TerminalSessionState.running => l10n.terminalStateConnected,
      TerminalSessionState.disconnected => l10n.terminalStateDisconnected,
      TerminalSessionState.ended => l10n.terminalStateEnded,
      TerminalSessionState.failed => l10n.terminalStateFailed,
    };

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.record});

  final SessionRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final host = ref.watch(hostProvider(record.hostId)).valueOrNull;

    return ListTile(
      leading: Icon(
        record.isPersistent ? Icons.play_circle_outline : Icons.terminal,
      ),
      title: Text(record.displayName),
      subtitle: Text(
        [
          if (host != null) host.name,
          if (record.tmuxSessionName != null) record.tmuxSessionName!,
          formatRelativeTime(l10n, record.lastUsedAt),
        ].join(' · '),
      ),
      onTap: () => resumeSessionRecord(context, ref, record),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _onMenu(context, ref, value, host),
        itemBuilder: (context) => [
          PopupMenuItem(value: 'resume', child: Text(l10n.actionResume)),
          PopupMenuItem(value: 'rename', child: Text(l10n.actionRename)),
          if (record.isPersistent && host != null)
            PopupMenuItem(value: 'kill', child: Text(l10n.sessionsKill)),
          PopupMenuItem(value: 'forget', child: Text(l10n.sessionsForget)),
        ],
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
    Host? host,
  ) async {
    final l10n = AppLocalizations.of(context);

    switch (value) {
      case 'resume':
        await resumeSessionRecord(context, ref, record);

      case 'rename':
        final name = await _askText(
          context,
          title: l10n.sessionsRenameTitle,
          initial: record.displayName,
        );
        if (name == null) return;
        await ref.read(sessionsRepositoryProvider).rename(record.id, name);

      case 'kill':
        if (host == null) return;
        final confirmed = await confirmDestructive(
          context,
          title: l10n.sessionsKillTitle,
          body: l10n.sessionsKillBody(
            record.tmuxSessionName ?? record.displayName,
          ),
          confirmLabel: l10n.sessionsKill,
        );
        if (!confirmed) return;

        try {
          final connection = await ref
              .read(connectionManagerProvider)
              .connect(host);
          await ref
              .read(tmuxServiceProvider)
              .killSession(connection, record.tmuxSessionName!);
          await ref.read(sessionsRepositoryProvider).delete(record.id);
        } on SshFailure catch (failure) {
          if (context.mounted) showFailure(context, failure);
        } on TmuxOperationException catch (error) {
          if (context.mounted) {
            showMessage(context, error.message, isError: true);
          }
        }

      case 'forget':
        // Only the local shortcut goes; remote work is untouched.
        final confirmed = await confirmDestructive(
          context,
          title: l10n.sessionsForget,
          body: l10n.sessionsForgetBody,
          confirmLabel: l10n.sessionsForget,
        );
        if (!confirmed) return;
        await ref.read(sessionsRepositoryProvider).delete(record.id);
    }
  }
}

/// On-demand tmux discovery for one host (SPEC 11.4).
class _HostTmuxSection extends ConsumerStatefulWidget {
  const _HostTmuxSection({required this.host});

  final Host host;

  @override
  ConsumerState<_HostTmuxSection> createState() => _HostTmuxSectionState();
}

class _HostTmuxSectionState extends ConsumerState<_HostTmuxSection> {
  List<TmuxSession>? _sessions;
  String? _unavailableReason;
  bool _loading = false;

  Future<void> _discover() async {
    setState(() {
      _loading = true;
      _unavailableReason = null;
    });

    try {
      final connection = await ref
          .read(connectionManagerProvider)
          .connect(widget.host);
      final tmux = ref.read(tmuxServiceProvider);

      final availability = await tmux.detect(connection);
      if (!availability.available) {
        if (mounted) {
          setState(() {
            _sessions = const [];
            _unavailableReason = availability.reason;
          });
        }
        return;
      }

      final sessions = await tmux.listSessions(connection);

      // Records for sessions that no longer exist are dropped, so the Continue
      // list cannot offer work that has already ended.
      await ref
          .read(sessionsRepositoryProvider)
          .pruneMissingTmux(
            hostId: widget.host.id,
            liveNames: sessions.map((session) => session.name).toSet(),
          );

      if (mounted) setState(() => _sessions = sessions);
    } on TmuxUnavailableException {
      if (mounted) {
        setState(() {
          _sessions = const [];
          _unavailableReason = AppLocalizations.of(context)
              .sessionsTmuxMissingBody;
        });
      }
    } on SshFailure catch (failure) {
      if (mounted) showFailure(context, failure);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sessions = _sessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.sessionsOnHost(widget.host.name),
          actionLabel: _loading ? null : l10n.sessionsRefresh,
          onAction: _loading ? null : _discover,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_unavailableReason != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _unavailableReason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => openHostTerminal(context, ref, widget.host),
                  child: Text(l10n.sessionsUseDirect),
                ),
              ],
            ),
          )
        else if (sessions == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.sessionsRefresh,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.sessionsEmptyBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final session in sessions)
            ListTile(
              leading: const Icon(Icons.view_compact_outlined),
              title: Text(
                session.name,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              subtitle: Text(
                [
                  l10n.sessionsWindows(session.windows),
                  if (session.attached) l10n.sessionsAttached,
                ].join(' · '),
              ),
              trailing: TextButton(
                onPressed: () =>
                    attachTmuxSession(context, ref, widget.host, session),
                child: Text(l10n.actionResume),
              ),
              onTap: () =>
                  attachTmuxSession(context, ref, widget.host, session),
            ),
      ],
    );
  }
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String initial,
}) {
  final controller = TextEditingController(text: initial);
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: Text(l10n.actionSave),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
