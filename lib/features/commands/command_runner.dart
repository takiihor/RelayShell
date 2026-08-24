import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/shell/command_variables.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import '../sessions/session_actions.dart';
import '../sessions/session_launcher.dart';
import '../terminal/terminal_providers.dart';

/// Runs a saved command end to end (SPEC 13).
///
/// The full path is: pick a target if the command is global → collect
/// `{{input:…}}` values → substitute → confirm if required → run. Each step is
/// skipped when it has nothing to ask, so a scoped, confirmation-free command
/// is genuinely one tap.
Future<void> runSavedCommand(
  BuildContext context,
  WidgetRef ref,
  SavedCommand command, {
  Host? host,
  Project? project,
}) async {
  final l10n = AppLocalizations.of(context);

  var targetHost = host;
  var targetProject = project;

  // Resolve the command's own scope first; it is more specific than context.
  if (command.projectId != null && targetProject == null) {
    targetProject = await ref.read(projectsRepositoryProvider).byId(
          command.projectId!,
        );
    if (targetProject != null) {
      targetHost = await ref.read(hostsRepositoryProvider).byId(
            targetProject.hostId,
          );
    }
  } else if (command.hostId != null && targetHost == null) {
    targetHost = await ref.read(hostsRepositoryProvider).byId(command.hostId!);
  }

  if (!context.mounted) return;

  // A global command has no target of its own, so ask which computer to use.
  if (targetHost == null) {
    final hosts = await ref.read(hostsRepositoryProvider).all();
    if (!context.mounted) return;
    if (hosts.isEmpty) {
      showMessage(context, l10n.errorNoHosts, isError: true);
      return;
    }
    targetHost = hosts.length == 1
        ? hosts.first
        : await _pickHost(context, hosts);
    if (targetHost == null) return;
  }

  if (!context.mounted) return;

  final launcher = ref.read(sessionLauncherProvider);

  final requests = launcher.inputsFor(command);
  var inputs = <String, String>{};
  if (requests.isNotEmpty) {
    final collected = await _collectInputs(context, command.name, requests);
    if (collected == null) return;
    inputs = collected;
  }

  if (!context.mounted) return;

  final PreparedCommand prepared;
  try {
    prepared = await launcher.prepare(
      command: command,
      host: targetHost,
      project: targetProject,
      inputs: inputs,
    );
  } on LaunchException catch (error) {
    if (context.mounted) showMessage(context, error.message, isError: true);
    return;
  }

  if (!context.mounted) return;

  if (prepared.needsConfirmation) {
    final confirmed = await _confirmCommand(context, prepared);
    if (!confirmed) return;
  }

  if (!context.mounted) return;

  if (prepared.command.isInteractive) {
    await _runInteractive(context, ref, prepared);
  } else {
    await _runOneShot(context, ref, prepared);
  }
}

Future<Host?> _pickHost(BuildContext context, List<Host> hosts) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<Host>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.commandRunOn,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final host in hosts)
                  ListTile(
                    leading: const Icon(Icons.computer_outlined),
                    title: Text(host.name),
                    subtitle: Text(host.displaySubtitle),
                    onTap: () => Navigator.of(context).pop(host),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Prompts for every `{{input:name}}` placeholder (SPEC 13.2).
Future<Map<String, String>?> _collectInputs(
  BuildContext context,
  String commandName,
  List<CommandInputRequest> requests,
) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _InputCollectorDialog(
      commandName: commandName,
      requests: requests,
    ),
  );
}

class _InputCollectorDialog extends StatefulWidget {
  const _InputCollectorDialog({
    required this.commandName,
    required this.requests,
  });

  final String commandName;
  final List<CommandInputRequest> requests;

  @override
  State<_InputCollectorDialog> createState() => _InputCollectorDialogState();
}

class _InputCollectorDialogState extends State<_InputCollectorDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final request in widget.requests)
      request.name: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.commandInputTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.commandName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < widget.requests.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              TextField(
                controller: _controllers[widget.requests[i].name],
                autofocus: i == 0,
                decoration: InputDecoration(
                  labelText: widget.requests[i].label,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            for (final entry in _controllers.entries) entry.key: entry.value.text,
          }),
          child: Text(l10n.actionContinue),
        ),
      ],
    );
  }
}

/// Shows the exact command before it runs (SPEC 13.3).
///
/// The preview is the substituted text, not the template, and any destructive
/// pattern is named. The wording never claims the command is safe — the app
/// cannot know that, and saying so would be worse than saying nothing.
Future<bool> _confirmCommand(
  BuildContext context,
  PreparedCommand prepared,
) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final dangerous = prepared.danger.hasSignals;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: dangerous
          ? Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error)
          : null,
      title: Text(
        dangerous ? l10n.commandDangerTitle : l10n.commandConfirmTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dangerous) ...[
              Text(l10n.commandDangerBody),
              const SizedBox(height: 12),
              for (final signal in prepared.danger.signals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${signal.pattern} — ${signal.explanation}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
            Text(l10n.commandPreview, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            CodeBlock(text: prepared.resolved, emphasis: dangerous),
            const SizedBox(height: 8),
            Text(
              '${prepared.host.name}'
              '${prepared.workingDirectory == null ? '' : ' · ${prepared.workingDirectory}'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: dangerous
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.actionRun),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<void> _runInteractive(
  BuildContext context,
  WidgetRef ref,
  PreparedCommand prepared,
) async {
  await openCommandTerminal(context, ref, prepared);
}

/// Runs a one-shot command and shows its output in a compact sheet (SPEC 12.4).
Future<void> _runOneShot(
  BuildContext context,
  WidgetRef ref,
  PreparedCommand prepared,
) async {
  final l10n = AppLocalizations.of(context);
  final launcher = ref.read(sessionLauncherProvider);

  final result = await showModalBottomSheet<OneShotResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _OneShotSheet(prepared: prepared, launcher: launcher),
  );

  if (result == null || !context.mounted) return;
  if (!result.succeeded && result.exitCode != null) {
    showMessage(context, l10n.commandExitCode(result.exitCode!));
  }
}

class _OneShotSheet extends StatefulWidget {
  const _OneShotSheet({required this.prepared, required this.launcher});

  final PreparedCommand prepared;
  final SessionLauncher launcher;

  @override
  State<_OneShotSheet> createState() => _OneShotSheetState();
}

class _OneShotSheetState extends State<_OneShotSheet> {
  OneShotResult? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final result = await widget.launcher.runOneShot(prepared: widget.prepared);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _result;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.prepared.command.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (result != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      result.succeeded
                          ? l10n.actionDone
                          : l10n.commandExitCode(result.exitCode ?? -1),
                    ),
                    backgroundColor: result.succeeded
                        ? null
                        : theme.colorScheme.errorContainer,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.prepared.host.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: SingleChildScrollView(
                child: switch ((result, _error)) {
                  (null, null) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: LoadingView(),
                    ),
                  (_, final Object error) => Text(
                      error.toString(),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  (final OneShotResult value, _) => CodeBlock(
                      text: value.output.trim().isEmpty
                          ? l10n.commandNoOutput
                          : value.output.trimRight(),
                    ),
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _result == null && _error == null ? null : _run,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.actionRetry),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_result),
                    child: Text(l10n.actionClose),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
