import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';
import '../sessions/session_actions.dart';

/// The projects list (SPEC 12, 32).
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsProvider);
    final hosts = ref.watch(hostsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.actionSearch,
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      floatingActionButton: projects.valueOrNull?.isEmpty ?? true
          ? null
          : FloatingActionButton(
              heroTag: 'add-project',
              onPressed: () => _addProject(context, hosts),
              child: const Icon(Icons.add),
            ),
      body: projects.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.folder_special_outlined,
              title: l10n.projectsEmptyTitle,
              body: l10n.projectsEmptyBody,
              actionLabel: l10n.projectsAdd,
              onAction: () => _addProject(context, hosts),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _ProjectCard(project: list[index]),
          );
        },
      ),
    );
  }

  void _addProject(BuildContext context, List<Host> hosts) {
    if (hosts.isEmpty) {
      showMessage(
        context,
        AppLocalizations.of(context).errorNoHosts,
        isError: true,
      );
      context.go(Routes.hostNew);
      return;
    }
    context.push(Routes.projectNew);
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final host = ref.watch(hostProvider(project.hostId)).valueOrNull;

    return Card(
      child: InkWell(
        onTap: () => context.go(Routes.projectDetail(project.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder_special_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                project.name,
                                style: theme.textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (project.favorite) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          host?.name ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (project.defaultSessionMode == SessionMode.persistent)
                    Tooltip(
                      message: l10n.sessionModePersistent,
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                project.remotePath,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (project.lastOpenedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.projectLastOpened(
                    formatRelativeTime(l10n, project.lastOpenedAt),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          openProjectTerminal(context, ref, project),
                      icon: const Icon(Icons.terminal, size: 18),
                      label: Text(l10n.projectOpenTerminal),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () => context.push(
                      '${Routes.files(project.hostId)}'
                      '?path=${Uri.encodeComponent(project.remotePath)}'
                      '&project=${project.id}',
                    ),
                    icon: const Icon(Icons.folder_outlined),
                    tooltip: l10n.projectBrowseFiles,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
