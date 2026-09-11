import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../shared/navigation/routes.dart';
import '../../core/platform/device_services.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';
import '../commands/command_runner.dart';
import '../hosts/host_card.dart';
import '../sessions/session_actions.dart';

/// The action dashboard (SPEC 7).
///
/// Home is not a terminal and not a host list. It answers "what was I doing,
/// and what do I want to do now" in one screen: sessions to resume, computers
/// to reach, projects to enter, commands to fire.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVisibleHosts());
  }

  /// Probes only the handful of hosts Home actually shows, once per visit.
  ///
  /// Deliberately not on a timer and not for every saved host: Home must not
  /// start dozens of network checks (SPEC 7.2, 36).
  Future<void> _refreshVisibleHosts() async {
    final hosts = ref.read(recentHostsProvider).value;
    if (hosts == null) return;
    final probe = ref.read(reachabilityProbeProvider);
    for (final host in hosts.take(3)) {
      await probe.probe(host, check: probeTcpPort);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hosts = ref.watch(recentHostsProvider);
    final allHosts = ref.watch(hostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.actionSearch,
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: allHosts.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (all) {
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.rocket_launch_outlined,
              title: l10n.homeEmptyTitle,
              body: l10n.homeEmptyBody,
              actionLabel: l10n.homeAddComputer,
              onAction: () => context.push(Routes.hostNew),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshVisibleHosts,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                const _ContinueSection(),
                _ComputersSection(hosts: hosts.value ?? const []),
                const _ProjectsSection(),
                const _QuickActionsSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Recently used sessions, offered for resume (SPEC 7.1).
class _ContinueSection extends ConsumerWidget {
  const _ContinueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(recentSessionsProvider).value ?? const [];
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.homeContinueTitle,
          actionLabel: l10n.homeSeeAll,
          onAction: () => context.go(Routes.sessions),
        ),
        for (final session in sessions.take(3))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ContinueCard(session: session),
          ),
      ],
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final host = ref.watch(hostProvider(session.hostId)).value;

    // The record itself does not know which backend anchored it, so the name
    // comes from the host. A Herdr session labelled "tmux" is worse than no
    // label at all.
    final subtitleParts = <String>[
      if (host != null) host.name,
      if (session.isPersistent)
        (host?.multiplexer ?? MultiplexerKind.tmux).storageValue
      else
        'shell',
    ];

    return Card(
      child: InkWell(
        onTap: () => resumeSessionRecord(context, ref, session),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                session.isPersistent
                    ? Icons.play_circle_outline
                    : Icons.terminal,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayName,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      formatRelativeTime(l10n, session.lastUsedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => resumeSessionRecord(context, ref, session),
                child: Text(l10n.actionResume),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned and recently used computers (SPEC 7.1).
class _ComputersSection extends ConsumerWidget {
  const _ComputersSection({required this.hosts});

  final List<Host> hosts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (hosts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.homeComputersTitle,
          actionLabel: l10n.homeSeeAll,
          onAction: () => context.go(Routes.hosts),
        ),
        for (final host in hosts)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: HostCard(host: host),
          ),
      ],
    );
  }
}

/// Pinned and recently opened projects (SPEC 7.1).
class _ProjectsSection extends ConsumerWidget {
  const _ProjectsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final projects = ref.watch(recentProjectsProvider).value ?? const [];
    if (projects.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.homeProjectsTitle,
          actionLabel: l10n.homeSeeAll,
          onAction: () => context.go(Routes.projects),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: projects.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final project = projects[index];
              final host = ref.watch(hostProvider(project.hostId)).value;
              return SizedBox(
                width: 220,
                child: Card(
                  child: InkWell(
                    onTap: () => context.go(Routes.projectDetail(project.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.folder_special_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  project.name,
                                  style: theme.textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            host?.name ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            shortenPath(project.remotePath, maxLength: 28),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Favourite commands, one tap from anywhere (SPEC 7.1).
class _QuickActionsSection extends ConsumerWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commands = ref.watch(favoriteCommandsProvider).value ?? const [];
    if (commands.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.homeQuickActionsTitle,
          actionLabel: l10n.homeSeeAll,
          onAction: () => context.push(Routes.commands),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final command in commands)
                ActionChip(
                  avatar: Icon(
                    command.isInteractive
                        ? Icons.terminal
                        : Icons.play_arrow_outlined,
                    size: 18,
                  ),
                  label: Text(command.name),
                  onPressed: () => runSavedCommand(context, ref, command),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
