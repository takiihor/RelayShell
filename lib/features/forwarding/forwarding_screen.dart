import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_indicator.dart';

/// Port forwarding, kept out of the main flow as an advanced tool (SPEC 16).
class ForwardingScreen extends ConsumerWidget {
  const ForwardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profiles = ref.watch(forwardProfilesProvider);
    final hosts = ref.watch(hostsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forwardingTitle)),
      floatingActionButton: profiles.valueOrNull?.isEmpty ?? true
          ? null
          : FloatingActionButton(
              heroTag: 'add-forward',
              onPressed: () => _edit(context, ref, hosts: hosts),
              child: const Icon(Icons.add),
            ),
      body: profiles.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.swap_horiz,
              title: l10n.forwardingEmptyTitle,
              body: l10n.forwardingEmptyBody,
              actionLabel: hosts.isEmpty ? null : l10n.forwardingAdd,
              onAction: hosts.isEmpty
                  ? null
                  : () => _edit(context, ref, hosts: hosts),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.forwardAdvancedNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final profile in list)
                _ForwardTile(
                  profile: profile,
                  onEdit: () =>
                      _edit(context, ref, hosts: hosts, existing: profile),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required List<Host> hosts,
    PortForwardProfile? existing,
  }) async {
    if (hosts.isEmpty) {
      showMessage(
        context,
        AppLocalizations.of(context).errorNoHosts,
        isError: true,
      );
      return;
    }

    final result = await showModalBottomSheet<PortForwardProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ForwardEditSheet(hosts: hosts, existing: existing),
    );

    if (result == null) return;
    await ref.read(forwardsRepositoryProvider).upsert(result);
  }
}

class _ForwardTile extends ConsumerWidget {
  const _ForwardTile({required this.profile, required this.onEdit});

  final PortForwardProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final host = ref.watch(hostProvider(profile.hostId)).valueOrNull;

    ref.watch(activeForwardsProvider);
    final active = ref.read(forwardingServiceProvider).forProfile(profile.id);
    final running = active?.isRunning ?? false;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: theme.textTheme.titleSmall),
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
                StatusIndicator(
                  status: running
                      ? SemanticStatus.connected
                      : SemanticStatus.inactive,
                  label: running ? l10n.forwardActive : l10n.forwardInactive,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              profile.summary,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (running && active != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  l10n.forwardStarted(active.boundPort),
                  l10n.forwardConnections(active.connectionCount),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: running
                      ? OutlinedButton.icon(
                          onPressed: () => ref
                              .read(forwardingServiceProvider)
                              .stop(profile.id),
                          icon: const Icon(Icons.stop, size: 18),
                          label: Text(l10n.actionStop),
                        )
                      : FilledButton.icon(
                          onPressed: host == null
                              ? null
                              : () => _start(context, ref, host),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(l10n.actionStart),
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref, Host host) async {
    final l10n = AppLocalizations.of(context);
    try {
      final connection =
          await ref.read(connectionManagerProvider).connect(host);
      final forward = await ref
          .read(forwardingServiceProvider)
          .start(connection, profile);
      if (context.mounted) {
        showMessage(context, l10n.forwardStarted(forward.boundPort));
      }
    } on SshFailure catch (failure) {
      if (context.mounted) showFailure(context, failure);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.forwardDeleteTitle,
      body: profile.name,
    );
    if (!confirmed) return;
    await ref.read(forwardingServiceProvider).stop(profile.id);
    await ref.read(forwardsRepositoryProvider).delete(profile.id);
  }
}

class _ForwardEditSheet extends StatefulWidget {
  const _ForwardEditSheet({required this.hosts, this.existing});

  final List<Host> hosts;
  final PortForwardProfile? existing;

  @override
  State<_ForwardEditSheet> createState() => _ForwardEditSheetState();
}

class _ForwardEditSheetState extends State<_ForwardEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _listenPort = TextEditingController(
    text: widget.existing?.listenPort.toString() ?? '8080',
  );
  late final _targetHost = TextEditingController(
    text: widget.existing?.targetHost ?? 'localhost',
  );
  late final _targetPort = TextEditingController(
    text: widget.existing?.targetPort?.toString() ?? '3000',
  );

  late String _hostId = widget.existing?.hostId ?? widget.hosts.first.id;
  late ForwardType _type = widget.existing?.type ?? ForwardType.local;

  @override
  void dispose() {
    _name.dispose();
    _listenPort.dispose();
    _targetHost.dispose();
    _targetPort.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    final existing = widget.existing;

    final profile = PortForwardProfile(
      id: existing?.id ?? const Uuid().v4(),
      hostId: _hostId,
      name: _name.text.trim(),
      type: _type,
      listenPort: int.parse(_listenPort.text.trim()),
      listenAddress: existing?.listenAddress ?? '127.0.0.1',
      targetHost:
          _type == ForwardType.dynamicSocks ? null : _targetHost.text.trim(),
      targetPort: _type == ForwardType.dynamicSocks
          ? null
          : int.tryParse(_targetPort.text.trim()),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final needsTarget = _type != ForwardType.dynamicSocks;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? l10n.forwardNew : l10n.forwardEdit,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.forwardFieldName),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? l10n.errorRequired
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _hostId,
                decoration: InputDecoration(labelText: l10n.forwardFieldHost),
                items: [
                  for (final host in widget.hosts)
                    DropdownMenuItem(value: host.id, child: Text(host.name)),
                ],
                onChanged: (value) =>
                    setState(() => _hostId = value ?? _hostId),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ForwardType>(
                initialValue: _type,
                decoration: InputDecoration(labelText: l10n.forwardFieldType),
                items: [
                  DropdownMenuItem(
                    value: ForwardType.local,
                    child: Text(l10n.forwardTypeLocal),
                  ),
                  DropdownMenuItem(
                    value: ForwardType.remote,
                    child: Text(l10n.forwardTypeRemote),
                  ),
                  DropdownMenuItem(
                    value: ForwardType.dynamicSocks,
                    child: Text(l10n.forwardTypeDynamic),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? ForwardType.local),
              ),
              const SizedBox(height: 6),
              Text(
                switch (_type) {
                  ForwardType.local => l10n.forwardTypeLocalHelp,
                  ForwardType.remote => l10n.forwardTypeRemoteHelp,
                  ForwardType.dynamicSocks => l10n.forwardTypeDynamicHelp,
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _listenPort,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    InputDecoration(labelText: l10n.forwardFieldListenPort),
                validator: _portValidator(l10n),
              ),
              if (needsTarget) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetHost,
                  autocorrect: false,
                  decoration:
                      InputDecoration(labelText: l10n.forwardFieldTargetHost),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? l10n.errorRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetPort,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      InputDecoration(labelText: l10n.forwardFieldTargetPort),
                  validator: _portValidator(l10n),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: Text(l10n.actionSave)),
            ],
          ),
        ),
      ),
    );
  }

  String? Function(String?) _portValidator(AppLocalizations l10n) => (value) {
        final port = int.tryParse(value?.trim() ?? '');
        if (port == null || port < 1 || port > 65535) {
          return l10n.errorInvalidPort;
        }
        return null;
      };
}
