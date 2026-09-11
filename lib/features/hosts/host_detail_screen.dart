import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../shared/navigation/routes.dart';
import '../../core/platform/wake_on_lan.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_indicator.dart';
import '../commands/command_runner.dart';
import '../sessions/session_actions.dart';
import '../terminal/terminal_providers.dart';

/// Everything you can do with one computer (SPEC 8.5).
class HostDetailScreen extends ConsumerWidget {
  const HostDetailScreen({required this.hostId, super.key});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final host = ref.watch(hostProvider(hostId));

    return host.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(error.toString())),
      ),
      data: (value) {
        if (value == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.help_outline,
              title: l10n.computersEmptyTitle,
              body: l10n.computersEmptyBody,
              actionLabel: l10n.computersAdd,
              onAction: () => context.push(Routes.hostNew),
            ),
          );
        }
        return _HostDetailView(host: value);
      },
    );
  }
}

class _HostDetailView extends ConsumerWidget {
  const _HostDetailView({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(hostConnectionStatusProvider(host.id)).value;
    final projects =
        ref.watch(projectsForHostProvider(host.id)).value ?? const [];
    final sessions =
        ref.watch(sessionsForHostProvider(host.id)).value ?? const [];
    final commands =
        ref
            .watch(scopedCommandsProvider(CommandScopeQuery(hostId: host.id)))
            .value ??
        const [];
    final forwards =
        ref.watch(forwardProfilesForHostProvider(host.id)).value ?? const [];
    final wol = ref.watch(wolProfileProvider(host.id)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(host.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.actionEdit,
            onPressed: () => context.push(Routes.hostEdit(host.id)),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _onMenu(context, ref, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'new-terminal',
                child: Text(l10n.computerNewTerminal),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Text(l10n.actionDuplicate),
              ),
              if (status?.state == SshConnectionState.connected)
                PopupMenuItem(
                  value: 'disconnect',
                  child: Text(l10n.actionDisconnect),
                ),
              PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.displaySubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      host.platform.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConnectionStatusIndicator(
                      state: status?.state ?? SshConnectionState.idle,
                    ),
                    if (host.environmentNotes?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 12),
                      Text(
                        host.environmentNotes!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => host.platform.supportsMultiplexer
                                ? openHostConversation(context, ref, host)
                                : openHostTerminal(context, ref, host),
                            icon: Icon(
                              host.platform.supportsMultiplexer
                                  ? Icons.chat_bubble_outline
                                  : Icons.terminal,
                              size: 18,
                            ),
                            label: Text(
                              host.platform.supportsMultiplexer
                                  ? l10n.computerRunCommand
                                  : l10n.computerOpenTerminal,
                            ),
                          ),
                        ),
                        if (host.platform.supportsMultiplexer) ...[
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () =>
                                openHostTerminal(context, ref, host),
                            icon: const Icon(Icons.terminal),
                            tooltip: l10n.computerOpenTerminal,
                          ),
                        ],
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () => context.push(Routes.files(host.id)),
                          icon: const Icon(Icons.folder_outlined),
                          tooltip: l10n.computerFiles,
                        ),
                      ],
                    ),
                    if (host.platform.supportsMultiplexer) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => openHostTerminal(
                          context,
                          ref,
                          host,
                          mode: SessionMode.persistent,
                        ),
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: Text(
                          l10n.sessionModePersistentNamed(
                            host.multiplexer.label,
                          ),
                        ),
                      ),
                    ],
                    if (wol != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _wake(context, wol),
                        icon: const Icon(Icons.power_settings_new, size: 18),
                        label: Text(l10n.actionWake),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (sessions.isNotEmpty) ...[
            SectionHeader(title: l10n.sessionsTitle),
            for (final session in sessions.take(5))
              ListTile(
                leading: Icon(
                  session.isPersistent
                      ? Icons.play_circle_outline
                      : Icons.terminal,
                ),
                title: Text(session.displayName),
                subtitle: Text(formatRelativeTime(l10n, session.lastUsedAt)),
                trailing: TextButton(
                  onPressed: () => resumeSessionRecord(context, ref, session),
                  child: Text(l10n.actionResume),
                ),
                onTap: () => resumeSessionRecord(context, ref, session),
              ),
          ],
          SectionHeader(
            title: l10n.computerProjects,
            actionLabel: l10n.actionAdd,
            onAction: () =>
                context.push('${Routes.projectNew}?host=${host.id}'),
          ),
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.projectsEmptyBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final project in projects)
              ListTile(
                leading: const Icon(Icons.folder_special_outlined),
                title: Text(project.name),
                subtitle: Text(
                  shortenPath(project.remotePath),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.projectDetail(project.id)),
              ),
          SectionHeader(
            title: l10n.commandsTitle,
            actionLabel: l10n.actionAdd,
            onAction: () =>
                context.push('${Routes.commandNew}?host=${host.id}'),
          ),
          if (commands.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.commandsEmptyBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final command in commands)
                    ActionChip(
                      avatar: Icon(
                        command.isInteractive
                            ? Icons.terminal
                            : Icons.play_arrow_outlined,
                        size: 18,
                      ),
                      label: Text(command.name),
                      onPressed: () =>
                          runSavedCommand(context, ref, command, host: host),
                    ),
                ],
              ),
            ),
          SectionHeader(
            title: l10n.forwardingTitle,
            actionLabel: l10n.actionAdd,
            onAction: () => context.push(Routes.forwarding),
          ),
          if (forwards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.forwardingEmptyBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final forward in forwards)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(forward.name),
                subtitle: Text(forward.summary),
                onTap: () => context.push(Routes.forwarding),
              ),
        ],
      ),
    );
  }

  Future<void> _wake(BuildContext context, WolProfile profile) async {
    final l10n = AppLocalizations.of(context);
    try {
      await const WakeOnLan().wake(profile);
      if (context.mounted) showMessage(context, l10n.wolSent);
    } on WakeOnLanException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final l10n = AppLocalizations.of(context);

    switch (value) {
      case 'new-terminal':
        await openAdditionalHostTerminal(context, ref, host);
      case 'duplicate':
        final now = DateTime.now();
        await ref
            .read(hostsRepositoryProvider)
            .upsert(
              Host(
                id: const Uuid().v4(),
                name: '${host.name} (${l10n.computerDuplicateSuffix})',
                hostname: host.hostname,
                port: host.port,
                username: host.username,
                authMethod: host.authMethod,
                credentialId: host.credentialId,
                startupDirectory: host.startupDirectory,
                environmentNotes: host.environmentNotes,
                colorValue: host.colorValue,
                platform: host.platform,
                createdAt: now,
                updatedAt: now,
              ),
            );
      case 'disconnect':
        await ref.read(connectionManagerProvider).disconnect(host.id);
      case 'delete':
        if (!context.mounted) return;
        final confirmed = await confirmDestructive(
          context,
          title: l10n.computerDeleteTitle,
          body: l10n.computerDeleteBody,
        );
        if (!confirmed) return;

        // Terminals and forwards are torn down first so nothing is left
        // pointing at a host row that is about to disappear.
        await ref.read(terminalManagerProvider).closeForHost(host.id);
        await ref.read(forwardingServiceProvider).stopForHost(host.id);
        await ref.read(connectionManagerProvider).disconnect(host.id);
        await ref.read(hostsRepositoryProvider).delete(host.id);
        if (context.mounted) context.go(Routes.hosts);
    }
  }
}
