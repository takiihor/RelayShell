import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../shared/navigation/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import 'ai_cli_presets.dart';
import 'command_runner.dart';

/// The saved-commands list (SPEC 13).
class CommandsScreen extends ConsumerWidget {
  const CommandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commands = ref.watch(commandsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.commandsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: l10n.presetsTitle,
            onPressed: () => offerAiCliPresets(context, ref),
          ),
        ],
      ),
      floatingActionButton: commands.value?.isEmpty ?? true
          ? null
          : FloatingActionButton(
              heroTag: 'add-command',
              onPressed: () => context.push(Routes.commandNew),
              child: const Icon(Icons.add),
            ),
      body: commands.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.bolt_outlined,
              title: l10n.commandsEmptyTitle,
              body: l10n.commandsEmptyBody,
              actionLabel: l10n.commandsAdd,
              onAction: () => context.push(Routes.commandNew),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _CommandTile(command: list[index]),
          );
        },
      ),
    );
  }
}

class _CommandTile extends ConsumerWidget {
  const _CommandTile({required this.command});

  final SavedCommand command;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final scopeLabel = switch (command.scope) {
      CommandScope.global => l10n.commandScopeGlobal,
      CommandScope.host => l10n.commandScopeHost,
      CommandScope.project => l10n.commandScopeProject,
    };

    return ListTile(
      leading: Icon(
        command.isInteractive ? Icons.terminal : Icons.play_arrow_outlined,
      ),
      title: Row(
        children: [
          Flexible(child: Text(command.name, overflow: TextOverflow.ellipsis)),
          if (command.favorite) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.star,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            command.command,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          Text(
            scopeLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'run':
              await runSavedCommand(context, ref, command);
            case 'favorite':
              await ref
                  .read(commandsRepositoryProvider)
                  .setFavorite(command.id, !command.favorite);
            case 'edit':
              context.push(Routes.commandEdit(command.id));
            case 'delete':
              final confirmed = await confirmDestructive(
                context,
                title: l10n.commandDeleteTitle,
                body: command.name,
              );
              if (!confirmed) return;
              await ref.read(commandsRepositoryProvider).delete(command.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'run', child: Text(l10n.actionRun)),
          PopupMenuItem(value: 'favorite', child: Text(l10n.commandFavorite)),
          PopupMenuItem(value: 'edit', child: Text(l10n.actionEdit)),
          PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
        ],
      ),
      onTap: () => runSavedCommand(context, ref, command),
    );
  }
}
