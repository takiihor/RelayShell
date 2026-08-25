import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../shared/navigation/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';

/// Create or edit a project (SPEC 40.2).
class ProjectEditScreen extends ConsumerStatefulWidget {
  const ProjectEditScreen({super.key, this.projectId, this.initialHostId});

  final String? projectId;
  final String? initialHostId;

  @override
  ConsumerState<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends ConsumerState<ProjectEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _path = TextEditingController();
  final _description = TextEditingController();
  final _tmuxName = TextEditingController();

  String? _hostId;
  SessionMode _sessionMode = SessionMode.direct;
  bool _favorite = false;

  Project? _existing;
  bool _loaded = false;

  bool get _isNew => widget.projectId == null;

  @override
  void initState() {
    super.initState();
    _hostId = widget.initialHostId;
    if (_isNew) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final project = await ref
        .read(projectsRepositoryProvider)
        .byId(widget.projectId!);
    if (!mounted) return;
    if (project == null) {
      setState(() => _loaded = true);
      return;
    }
    setState(() {
      _existing = project;
      _name.text = project.name;
      _path.text = project.remotePath;
      _description.text = project.description ?? '';
      _tmuxName.text = project.defaultTmuxName ?? '';
      _hostId = project.hostId;
      _sessionMode = project.defaultSessionMode;
      _favorite = project.favorite;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _path.dispose();
    _description.dispose();
    _tmuxName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final hostId = _hostId;
    if (hostId == null) return;

    final now = DateTime.now();
    final existing = _existing;

    final project = existing == null
        ? Project(
            id: const Uuid().v4(),
            name: _name.text.trim(),
            hostId: hostId,
            remotePath: _path.text.trim(),
            description: _nullIfEmpty(_description.text),
            defaultSessionMode: _sessionMode,
            defaultTmuxName: _nullIfEmpty(_tmuxName.text),
            favorite: _favorite,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            name: _name.text.trim(),
            hostId: hostId,
            remotePath: _path.text.trim(),
            description: _nullIfEmpty(_description.text),
            defaultSessionMode: _sessionMode,
            defaultTmuxName: _nullIfEmpty(_tmuxName.text),
            favorite: _favorite,
            updatedAt: now,
          );

    await ref.read(projectsRepositoryProvider).upsert(project);
    if (!mounted) return;
    context.go(Routes.projectDetail(project.id));
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

    if (!_loaded) return const Scaffold(body: LoadingView());

    final selectedHost = hosts.where((host) => host.id == _hostId).firstOrNull;
    final supportsTmux = selectedHost?.platform.supportsTmux ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.projectNew : l10n.projectEdit),
        actions: [TextButton(onPressed: _save, child: Text(l10n.actionSave))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.projectFieldName),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _hostId,
              decoration: InputDecoration(labelText: l10n.projectFieldHost),
              items: [
                for (final host in hosts)
                  DropdownMenuItem(value: host.id, child: Text(host.name)),
              ],
              onChanged: (value) => setState(() {
                _hostId = value;
                // A Windows host cannot host a tmux session, so a default that
                // would silently downgrade is corrected here instead.
                final host = hosts.where((h) => h.id == value).firstOrNull;
                if (host != null && !host.platform.supportsTmux) {
                  _sessionMode = SessionMode.direct;
                }
              }),
              validator: (value) => value == null ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _path,
              autocorrect: false,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: l10n.projectFieldPath,
                hintText: l10n.projectFieldPathHint,
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.projectFieldDescription,
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 20),
            Text(
              l10n.projectFieldSessionMode,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<SessionMode>(
              segments: [
                ButtonSegment(
                  value: SessionMode.direct,
                  label: Text(l10n.sessionModeDirect),
                  icon: const Icon(Icons.terminal, size: 18),
                ),
                ButtonSegment(
                  value: SessionMode.persistent,
                  label: Text(l10n.sessionModePersistent),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  enabled: supportsTmux,
                ),
              ],
              selected: {_sessionMode},
              onSelectionChanged: (values) =>
                  setState(() => _sessionMode = values.first),
            ),
            const SizedBox(height: 6),
            Text(
              _sessionMode == SessionMode.persistent
                  ? l10n.sessionModePersistentHelp
                  : l10n.sessionModeDirectHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!supportsTmux) ...[
              const SizedBox(height: 6),
              Text(
                l10n.sessionsTmuxMissingBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_sessionMode == SessionMode.persistent) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _tmuxName,
                autocorrect: false,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: l10n.projectFieldTmuxName,
                  helperText: l10n.projectFieldTmuxNameHelp,
                ),
              ),
            ],

            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _favorite,
              title: Text(l10n.projectFavorite),
              onChanged: (value) => setState(() => _favorite = value),
            ),
          ],
        ),
      ),
    );
  }
}
