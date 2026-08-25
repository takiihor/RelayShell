import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../core/platform/wake_on_lan.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_indicator.dart';
import '../sessions/session_actions.dart';

/// A computer, with its one clear primary action (SPEC 7.1, 39).
///
/// "Connect" is the primary action and everything else is secondary or in the
/// overflow, because the card exists to get the user onto the machine.
class HostCard extends ConsumerWidget {
  const HostCard({required this.host, super.key, this.showActions = true});

  final Host host;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final connectionStatus =
        ref.watch(hostConnectionStatusProvider(host.id)).valueOrNull;
    final reachability = ref.watch(hostReachabilityProvider(host.id));
    final isConnected = connectionStatus?.state == SshConnectionState.connected;
    final wol = ref.watch(wolProfileProvider(host.id)).valueOrNull;

    return Card(
      child: InkWell(
        onTap: () => context.go(Routes.hostDetail(host.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _HostAvatar(host: host),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                host.name,
                                style: theme.textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (host.favorite) ...[
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
                          host.displaySubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (showActions)
                    _HostOverflowMenu(host: host, wol: wol),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Once connected, the live state is the truth; the advisory
                  // reachability probe stops being interesting.
                  if (isConnected || (connectionStatus?.state.isBusy ?? false))
                    ConnectionStatusIndicator(state: connectionStatus!.state)
                  else
                    ReachabilityIndicator(reachability: reachability),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      host.lastConnectedAt == null
                          ? l10n.computerNeverConnected
                          : l10n.computerLastConnected(
                              formatRelativeTime(l10n, host.lastConnectedAt),
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => openHostTerminal(context, ref, host),
                        icon: const Icon(Icons.terminal, size: 18),
                        label: Text(l10n.actionConnect),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () => context.push(Routes.files(host.id)),
                      icon: const Icon(Icons.folder_outlined),
                      tooltip: l10n.computerFiles,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  const _HostAvatar({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = host.colorValue == null
        ? theme.colorScheme.primaryContainer
        : Color(host.colorValue!);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(
        host.platform.isWindows ? Icons.desktop_windows_outlined : Icons.dns_outlined,
        size: 20,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _HostOverflowMenu extends ConsumerWidget {
  const _HostOverflowMenu({required this.host, this.wol});

  final Host host;
  final WolProfile? wol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'new-terminal':
            await openAdditionalHostTerminal(context, ref, host);
          case 'files':
            context.push(Routes.files(host.id));
          case 'projects':
            context.go(Routes.hostDetail(host.id));
          case 'edit':
            context.push(Routes.hostEdit(host.id));
          case 'favorite':
            await ref
                .read(hostsRepositoryProvider)
                .setFavorite(host.id, !host.favorite);
          case 'wake':
            await _wake(context, ref);
          case 'disconnect':
            await ref.read(connectionManagerProvider).disconnect(host.id);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'new-terminal',
          child: ListTile(
            leading: const Icon(Icons.terminal),
            title: Text(l10n.computerNewTerminal),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'files',
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.computerFiles),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (wol != null)
          PopupMenuItem(
            value: 'wake',
            child: ListTile(
              leading: const Icon(Icons.power_settings_new),
              title: Text(l10n.actionWake),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem(
          value: 'favorite',
          child: ListTile(
            leading: Icon(
              host.favorite ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            title: Text(l10n.computerFavorite),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.actionEdit),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (ref.read(connectionManagerProvider).isConnected(host.id))
          PopupMenuItem(
            value: 'disconnect',
            child: ListTile(
              leading: const Icon(Icons.link_off),
              title: Text(l10n.actionDisconnect),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Future<void> _wake(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final profile = wol;
    if (profile == null) return;
    try {
      await const WakeOnLan().wake(profile);
      if (context.mounted) showMessage(context, l10n.wolSent);
    } on WakeOnLanException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    }
  }
}
