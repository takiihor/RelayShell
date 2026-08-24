import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/common.dart';
import 'host_card.dart';

/// The computers list (SPEC 8, 32).
class HostsScreen extends ConsumerWidget {
  const HostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hosts = ref.watch(hostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.computersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.computersAdd,
            onPressed: () => context.push(Routes.hostNew),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.actionSearch,
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      floatingActionButton: hosts.valueOrNull?.isEmpty ?? true
          ? null
          : FloatingActionButton(
              heroTag: 'add-host',
              onPressed: () => context.push(Routes.hostNew),
              child: const Icon(Icons.add),
            ),
      body: hosts.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.computer_outlined,
              title: l10n.computersEmptyTitle,
              body: l10n.computersEmptyBody,
              actionLabel: l10n.computersAdd,
              onAction: () => context.push(Routes.hostNew),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => HostCard(host: list[index]),
          );
        },
      ),
    );
  }
}
