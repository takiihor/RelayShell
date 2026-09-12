import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/shell/command_variables.dart';
import '../../core/shell/danger_analysis.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';

/// Create or edit a saved command (SPEC 13.1).
class CommandEditScreen extends ConsumerStatefulWidget {
  const CommandEditScreen({
    super.key,
    this.commandId,
    this.initialHostId,
    this.initialProjectId,
    this.initialCommand,
  });

  final String? commandId;
  final String? initialHostId;
  final String? initialProjectId;
  final String? initialCommand;

  @override
  ConsumerState<CommandEditScreen> createState() => _CommandEditScreenState();
}

class _CommandEditScreenState extends ConsumerState<CommandEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _command = TextEditingController();
  final _workingDirectory = TextEditingController();

  CommandScope _scope = CommandScope.global;
  ExecutionMode _executionMode = ExecutionMode.oneShot;
  ConfirmationMode _confirmationMode = ConfirmationMode.dangerous;
  SessionMode _sessionMode = SessionMode.direct;
  String? _hostId;
  String? _projectId;
  bool _favorite = false;

  SavedCommand? _existing;
  bool _loaded = false;

  bool get _isNew => widget.commandId == null;

  @override
  void initState() {
    super.initState();
    _hostId = widget.initialHostId;
    _projectId = widget.initialProjectId;
    if (_projectId != null) {
      _scope = CommandScope.project;
    } else if (_hostId != null) {
      _scope = CommandScope.host;
    }

    if (_isNew) {
      _command.text = widget.initialCommand ?? '';
      _loaded = true;
    } else {
      _load();
    }
    _command.addListener(() => setState(() {}));
  }

  Future<void> _load() async {
    final command = await ref
        .read(commandsRepositoryProvider)
        .byId(widget.commandId!);
    if (!mounted) return;
    if (command == null) {
      setState(() => _loaded = true);
      return;
    }
    setState(() {
      _existing = command;
      _name.text = command.name;
      _command.text = command.command;
      _workingDirectory.text = command.workingDirectory ?? '';
      _scope = command.scope;
      _executionMode = command.executionMode;
      _confirmationMode = command.confirmationMode;
      _sessionMode = command.sessionMode;
      _hostId = command.hostId;
      _projectId = command.projectId;
      _favorite = command.favorite;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _workingDirectory.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final now = DateTime.now();
    final existing = _existing;

    final command = existing == null
        ? SavedCommand(
            id: const Uuid().v4(),
            name: _name.text.trim(),
            command: _command.text.trim(),
            scope: _scope,
            hostId: _scope == CommandScope.host ? _hostId : null,
            projectId: _scope == CommandScope.project ? _projectId : null,
            workingDirectory: _nullIfEmpty(_workingDirectory.text),
            executionMode: _executionMode,
            confirmationMode: _confirmationMode,
            sessionMode: _sessionMode,
            favorite: _favorite,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            name: _name.text.trim(),
            command: _command.text.trim(),
            scope: _scope,
            hostId: _scope == CommandScope.host ? _hostId : null,
            projectId: _scope == CommandScope.project ? _projectId : null,
            workingDirectory: _nullIfEmpty(_workingDirectory.text),
            executionMode: _executionMode,
            confirmationMode: _confirmationMode,
            sessionMode: _sessionMode,
            favorite: _favorite,
            updatedAt: now,
          );

    await ref.read(commandsRepositoryProvider).upsert(command);
    if (mounted) context.pop();
  }

  static String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hosts = ref.watch(hostsProvider).value ?? const [];
    final projects = ref.watch(projectsProvider).value ?? const [];

    if (!_loaded) return const Scaffold(body: LoadingView());

    final danger = const DangerAnalyzer().analyze(_command.text);
    final inputs = const CommandVariableResolver().inputsIn(_command.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.commandNew : l10n.commandEdit),
        actions: [TextButton(onPressed: _save, child: Text(l10n.actionSave))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.commandFieldName),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _command,
              maxLines: 4,
              minLines: 2,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: l10n.commandFieldCommand,
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.commandVariablesHelp(
                '{{project_path}}',
                '{{host_name}}',
                '{{input:name}}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (inputs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final input in inputs)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(input.label),
                    ),
                ],
              ),
            ],

            // Warn while editing, not only at run time, so the flag can be set
            // deliberately rather than discovered mid-command (SPEC 13.3).
            if (danger.hasSignals) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.commandDangerTitle,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final signal in danger.signals)
                      Text(
                        '• ${signal.pattern} — ${signal.explanation}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            Text(l10n.commandFieldScope, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<CommandScope>(
              segments: [
                ButtonSegment(
                  value: CommandScope.global,
                  label: Text(l10n.commandScopeGlobal),
                ),
                ButtonSegment(
                  value: CommandScope.host,
                  label: Text(l10n.commandScopeHost),
                  enabled: hosts.isNotEmpty,
                ),
                ButtonSegment(
                  value: CommandScope.project,
                  label: Text(l10n.commandScopeProject),
                  enabled: projects.isNotEmpty,
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (values) =>
                  setState(() => _scope = values.first),
            ),
            if (_scope == CommandScope.host) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: hosts.any((h) => h.id == _hostId)
                    ? _hostId
                    : null,
                decoration: InputDecoration(labelText: l10n.commandFieldHost),
                items: [
                  for (final host in hosts)
                    DropdownMenuItem(value: host.id, child: Text(host.name)),
                ],
                onChanged: (value) => setState(() => _hostId = value),
                validator: (value) => value == null ? l10n.errorRequired : null,
              ),
            ],
            if (_scope == CommandScope.project) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: projects.any((p) => p.id == _projectId)
                    ? _projectId
                    : null,
                decoration: InputDecoration(
                  labelText: l10n.commandFieldProject,
                ),
                items: [
                  for (final project in projects)
                    DropdownMenuItem(
                      value: project.id,
                      child: Text(project.name),
                    ),
                ],
                onChanged: (value) => setState(() => _projectId = value),
                validator: (value) => value == null ? l10n.errorRequired : null,
              ),
            ],

            const SizedBox(height: 12),
            TextFormField(
              controller: _workingDirectory,
              autocorrect: false,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: l10n.commandFieldWorkingDirectory,
              ),
            ),

            const SizedBox(height: 20),
            Text(
              l10n.commandFieldExecutionMode,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ExecutionMode>(
              segments: [
                ButtonSegment(
                  value: ExecutionMode.oneShot,
                  label: Text(l10n.commandModeOneShot),
                  icon: const Icon(Icons.play_arrow_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ExecutionMode.interactive,
                  label: Text(l10n.commandModeInteractive),
                  icon: const Icon(Icons.terminal, size: 18),
                ),
              ],
              selected: {_executionMode},
              onSelectionChanged: (values) =>
                  setState(() => _executionMode = values.first),
            ),
            const SizedBox(height: 6),
            Text(
              _executionMode == ExecutionMode.interactive
                  ? l10n.commandModeInteractiveHelp
                  : l10n.commandModeOneShotHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_executionMode == ExecutionMode.interactive) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<SessionMode>(
                initialValue: _sessionMode,
                decoration: InputDecoration(
                  labelText: l10n.commandFieldSessionMode,
                ),
                items: [
                  DropdownMenuItem(
                    value: SessionMode.direct,
                    child: Text(l10n.sessionModeDirect),
                  ),
                  DropdownMenuItem(
                    value: SessionMode.persistent,
                    child: Text(l10n.sessionModePersistent),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _sessionMode = value ?? SessionMode.direct),
              ),
            ],

            const SizedBox(height: 16),
            DropdownButtonFormField<ConfirmationMode>(
              initialValue: _confirmationMode,
              decoration: InputDecoration(
                labelText: l10n.commandFieldConfirmation,
              ),
              items: [
                DropdownMenuItem(
                  value: ConfirmationMode.none,
                  child: Text(l10n.commandConfirmNone),
                ),
                DropdownMenuItem(
                  value: ConfirmationMode.dangerous,
                  child: Text(l10n.commandConfirmDangerous),
                ),
                DropdownMenuItem(
                  value: ConfirmationMode.always,
                  child: Text(l10n.commandConfirmAlways),
                ),
              ],
              onChanged: (value) => setState(
                () => _confirmationMode = value ?? ConfirmationMode.dangerous,
              ),
            ),

            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _favorite,
              title: Text(l10n.commandFavorite),
              onChanged: (value) => setState(() => _favorite = value),
            ),
          ],
        ),
      ),
    );
  }
}
