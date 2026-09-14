import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/device_services.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/navigation/routes.dart';
import '../../shared/widgets/common.dart';
import '../hosts/host_card.dart';

/// The entry point for remote development.
///
/// A computer is only a way into a conversation, so this screen deliberately
/// stays small: choose a computer, then work in its Conversation Shell.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshHosts());
  }

  Future<void> _refreshHosts() async {
    final hosts = ref.read(hostsProvider).value;
    if (hosts == null) return;

    final probe = ref.read(reachabilityProbeProvider);
    for (final host in hosts.take(6)) {
      await probe.probe(host, check: probeTcpPort);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hosts = ref.watch(hostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.moreSettings,
          ),
        ],
      ),
      floatingActionButton: hosts.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.hostNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.homeAddComputer),
            )
          : null,
      body: hosts.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.terminal_outlined,
              title: l10n.homeEmptyTitle,
              body: l10n.homeEmptyBody,
              actionLabel: l10n.homeAddComputer,
              onAction: () => context.push(Routes.hostNew),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshHosts,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              children: [
                Text(
                  l10n.homeConversationTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeConversationBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.homeComputersTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final host in items) ...[
                  HostCard(host: host),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
