import 'package:flutter/material.dart';

import '../terminal/herdr_panes_sheet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../shared/navigation/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';
import '../commands/ai_cli_presets.dart';
import '../commands/command_runner.dart';
import '../sessions/session_actions.dart';

/// The project dashboard (SPEC 12.2).
///
/// This is the screen the product is really about: one tap from here starts the
/// tool the user came for, in the right directory, in a session that survives a
/// dropped connection.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));

    return project.when(
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
              title: AppLocalizations.of(context).projectsEmptyTitle,
              body: AppLocalizations.of(context).projectsEmptyBody,
            ),
          );
        }
        return _ProjectDetailView(project: value);
      },
    );
  }
}

class _ProjectDetailView extends ConsumerWidget {
  const _ProjectDetailView({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final host = ref.watch(hostProvider(project.hostId)).value;
    final supportsConversation = host?.platform == RemotePlatform.posix;
    final commands =
        ref
            .watch(
              scopedCommandsProvider(
                CommandScopeQuery(
                  hostId: project.hostId,
                  projectId: project.id,
                ),
              ),
            )
            .value ??
        const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: Icon(
              project.favorite ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            tooltip: l10n.projectFavorite,
            onPressed: () => ref
                .read(projectsRepositoryProvider)
                .setFavorite(project.id, !project.favorite),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.actionEdit,
            onPressed: () => context.push(Routes.projectEdit(project.id)),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'delete') return;
              final confirmed = await confirmDestructive(
                context,
                title: l10n.projectDeleteTitle,
                body: l10n.projectDeleteBody,
              );
              if (!confirmed) return;
              await ref.read(projectsRepositoryProvider).delete(project.id);
              if (context.mounted) context.go(Routes.projects);
            },
            itemBuilder: (context) => [
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
                    Row(
                      children: [
                        Icon(
                          Icons.computer_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            host?.name ?? '',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      project.remotePath,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (project.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 10),
                      Text(
                        project.description!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      project.defaultSessionMode == SessionMode.persistent
                          ? l10n.sessionModePersistent
                          : l10n.sessionModeDirect,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (host != null &&
                        host.platform == RemotePlatform.posix &&
                        host.multiplexer == MultiplexerKind.herdr)
                      FilledButton.icon(
                        onPressed: () => showHerdrPanes(
                          context,
                          ref,
                          host,
                          project: project,
                        ),
                        icon: const Icon(Icons.dashboard_outlined),
                        label: Text(l10n.herdrPanes),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => supportsConversation
                                ? openProjectConversation(
                                    context,
                                    ref,
                                    project,
                                  )
                                : openProjectTerminal(context, ref, project),
                            icon: Icon(
                              supportsConversation
                                  ? Icons.chat_bubble_outline
                                  : Icons.terminal,
                              size: 18,
                            ),
                            label: Text(
                              supportsConversation
                                  ? l10n.computerRunCommand
                                  : l10n.projectOpenTerminal,
                            ),
                          ),
                        ),
                        if (supportsConversation) ...[
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () =>
                                openProjectTerminal(context, ref, project),
                            icon: const Icon(Icons.terminal),
                            tooltip: l10n.projectOpenTerminal,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SectionHeader(
            title: l10n.projectActionsTitle,
            actionLabel: l10n.actionAdd,
            onAction: () => context.push(
              '${Routes.commandNew}?project=${project.id}&host=${project.hostId}',
            ),
          ),
          if (commands.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.projectNoActionsBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        offerAiCliPresets(context, ref, project: project),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(l10n.presetsTitle),
                  ),
                ],
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
                      onPressed: () => runSavedCommand(
                        context,
                        ref,
                        command,
                        host: host,
                        project: project,
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(l10n.presetsTitle),
                    onPressed: () =>
                        offerAiCliPresets(context, ref, project: project),
                  ),
                ],
              ),
            ),

          SectionHeader(title: l10n.projectFilesTitle),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.projectBrowseFiles),
            subtitle: Text(
              shortenPath(project.remotePath),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              '${Routes.files(project.hostId)}'
              '?path=${Uri.encodeComponent(project.remotePath)}'
              '&project=${project.id}',
            ),
          ),
        ],
      ),
    );
  }
}
