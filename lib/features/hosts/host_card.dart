import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/navigation/routes.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/status_indicator.dart';
import '../sessions/session_actions.dart';
import '../terminal/herdr_panes_sheet.dart';

/// A saved SSH connection and its one primary action: open Conversation Shell.
class HostCard extends ConsumerWidget {
  const HostCard({required this.host, super.key, this.showActions = true});

  final Host host;
  final bool showActions;

  Future<void> _open(BuildContext context, WidgetRef ref) {
    if (host.platform == RemotePlatform.posix) {
      return openHostConversation(context, ref, host);
    }
    return openHostTerminal(context, ref, host);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final connectionStatus = ref
        .watch(hostConnectionStatusProvider(host.id))
        .value;
    final reachability = ref.watch(hostReachabilityProvider(host.id));
    final isConnected = connectionStatus?.state == SshConnectionState.connected;
    final openLabel = host.platform == RemotePlatform.posix
        ? l10n.conversationOpen
        : l10n.computerOpenTerminal;

    return Semantics(
      button: true,
      label: '$openLabel ${host.name}',
      child: Card(
        child: InkWell(
          onTap: () => _open(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                          Text(
                            host.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
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
                    if (showActions) _HostOverflowMenu(host: host),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (isConnected ||
                        (connectionStatus?.state.isBusy ?? false))
                      ConnectionStatusIndicator(state: connectionStatus!.state)
                    else
                      ReachabilityIndicator(reachability: reachability),
                    const Spacer(),
                    if (host.lastConnectedAt != null)
                      Flexible(
                        child: Text(
                          l10n.computerLastConnected(
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _open(context, ref),
                      icon: Icon(
                        host.platform == RemotePlatform.posix
                            ? Icons.chat_bubble_outline
                            : Icons.terminal,
                        size: 18,
                      ),
                      label: Text(openLabel),
                    ),
                  ),
                  if (host.platform == RemotePlatform.posix) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showHerdrPanes(context, ref, host),
                        icon: const Icon(Icons.grid_view_outlined, size: 18),
                        label: Text(l10n.herdrPanes),
                      ),
                    ),
                  ],
                ],
              ],
            ),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        host.platform.isWindows
            ? Icons.desktop_windows_outlined
            : Icons.dns_outlined,
        size: 22,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _HostOverflowMenu extends ConsumerWidget {
  const _HostOverflowMenu({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.actionEdit,
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            context.push(Routes.hostEdit(host.id));
          case 'favorite':
            await ref
                .read(hostsRepositoryProvider)
                .setFavorite(host.id, !host.favorite);
          case 'disconnect':
            await ref.read(connectionManagerProvider).disconnect(host.id);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: Text(l10n.computerEdit),
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
}
