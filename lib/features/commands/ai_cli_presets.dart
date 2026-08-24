import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';

/// A ready-made command the user can add with one tap (SPEC 14).
class CommandPreset {
  const CommandPreset({
    required this.id,
    required this.command,
    required this.executionMode,
    required this.sessionMode,
    required this.icon,
    this.confirmationMode = ConfirmationMode.dangerous,
  });

  final String id;
  final String command;
  final ExecutionMode executionMode;
  final SessionMode sessionMode;
  final ConfirmationMode confirmationMode;
  final IconData icon;
}

/// Built-in presets.
///
/// AI CLIs are ordinary project actions with convenient defaults — interactive,
/// in a persistent session — precisely because the app does not proxy the model
/// or hold any provider credentials (SPEC 14). Sign-in stays on the computer.
class CommandPresets {
  const CommandPresets._();

  static const List<CommandPreset> aiTools = [
    CommandPreset(
      id: 'codex',
      command: 'codex',
      executionMode: ExecutionMode.interactive,
      sessionMode: SessionMode.persistent,
      confirmationMode: ConfirmationMode.none,
      icon: Icons.auto_awesome,
    ),
    CommandPreset(
      id: 'claude',
      command: 'claude',
      executionMode: ExecutionMode.interactive,
      sessionMode: SessionMode.persistent,
      confirmationMode: ConfirmationMode.none,
      icon: Icons.auto_awesome,
    ),
    CommandPreset(
      id: 'gemini',
      command: 'gemini',
      executionMode: ExecutionMode.interactive,
      sessionMode: SessionMode.persistent,
      confirmationMode: ConfirmationMode.none,
      icon: Icons.auto_awesome,
    ),
  ];

  static const List<CommandPreset> development = [
    CommandPreset(
      id: 'git_status',
      command: 'git status',
      executionMode: ExecutionMode.oneShot,
      sessionMode: SessionMode.direct,
      confirmationMode: ConfirmationMode.none,
      icon: Icons.difference_outlined,
    ),
    CommandPreset(
      id: 'git_pull',
      command: 'git pull',
      executionMode: ExecutionMode.oneShot,
      sessionMode: SessionMode.direct,
      icon: Icons.download_outlined,
    ),
    CommandPreset(
      id: 'dev_server',
      command: 'npm run dev',
      executionMode: ExecutionMode.interactive,
      sessionMode: SessionMode.persistent,
      confirmationMode: ConfirmationMode.none,
      icon: Icons.play_arrow_outlined,
    ),
  ];

  static const List<CommandPreset> system = [
    CommandPreset(
      id: 'docker_ps',
      command: 'docker ps',
      executionMode: ExecutionMode.oneShot,
      sessionMode: SessionMode.direct,
      confirmationMode: ConfirmationMode.none,
      icon: Icons.inventory_2_outlined,
    ),
    CommandPreset(
      id: 'disk_usage',
      command: 'df -h',
      executionMode: ExecutionMode.oneShot,
      sessionMode: SessionMode.direct,
      confirmationMode: ConfirmationMode.none,
      icon: Icons.storage_outlined,
    ),
    CommandPreset(
      id: 'system_status',
      command: 'uptime && free -h',
      executionMode: ExecutionMode.oneShot,
      sessionMode: SessionMode.direct,
      confirmationMode: ConfirmationMode.none,
      icon: Icons.monitor_heart_outlined,
    ),
  ];

  /// The localised label for a preset.
  static String labelFor(AppLocalizations l10n, String id) => switch (id) {
        'codex' => l10n.presetCodex,
        'claude' => l10n.presetClaudeCode,
        'gemini' => l10n.presetGeminiCli,
        'git_status' => l10n.presetGitStatus,
        'git_pull' => l10n.presetGitPull,
        'dev_server' => l10n.presetStartDevServer,
        'docker_ps' => l10n.presetDockerPs,
        'disk_usage' => l10n.presetDiskUsage,
        'system_status' => l10n.presetSystemStatus,
        _ => l10n.presetCustomCli,
      };
}

/// Offers presets to add as actions for a project or host (SPEC 14).
Future<void> offerAiCliPresets(
  BuildContext context,
  WidgetRef ref, {
  Project? project,
  Host? host,
}) async {
  final l10n = AppLocalizations.of(context);

  final selected = await showModalBottomSheet<CommandPreset>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                l10n.presetsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                l10n.presetsAiNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            for (final group in [
              CommandPresets.aiTools,
              CommandPresets.development,
              CommandPresets.system,
            ]) ...[
              const Divider(height: 1),
              for (final preset in group)
                ListTile(
                  leading: Icon(preset.icon),
                  title: Text(CommandPresets.labelFor(l10n, preset.id)),
                  subtitle: Text(
                    preset.command,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  onTap: () => Navigator.of(context).pop(preset),
                ),
            ],
          ],
        ),
      ),
    ),
  );

  if (selected == null || !context.mounted) return;

  final now = DateTime.now();
  final scope = project != null
      ? CommandScope.project
      : host != null
          ? CommandScope.host
          : CommandScope.global;

  await ref.read(commandsRepositoryProvider).upsert(
        SavedCommand(
          id: const Uuid().v4(),
          name: CommandPresets.labelFor(l10n, selected.id),
          command: selected.command,
          scope: scope,
          hostId: scope == CommandScope.host ? host?.id : null,
          projectId: scope == CommandScope.project ? project?.id : null,
          executionMode: selected.executionMode,
          confirmationMode: selected.confirmationMode,
          sessionMode: selected.sessionMode,
          createdAt: now,
          updatedAt: now,
        ),
      );

  if (context.mounted) showMessage(context, l10n.filesSaved);
}
