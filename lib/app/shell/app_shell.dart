import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/terminal/terminal_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/navigation/routes.dart';

/// The tabbed frame around the main sections (SPEC 6).
///
/// Switches from a bottom bar to a navigation rail on wide screens, because a
/// bottom bar on a tablet in landscape puts the primary navigation as far from
/// the hands as the layout allows.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Below this width, a bottom navigation bar; above it, a rail.
  static const double railBreakpoint = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (icon: Icons.home_outlined, selected: Icons.home, label: l10n.navHome),
      (
        icon: Icons.computer_outlined,
        selected: Icons.computer,
        label: l10n.navComputers,
      ),
      (
        icon: Icons.folder_special_outlined,
        selected: Icons.folder_special,
        label: l10n.navProjects,
      ),
      (
        icon: Icons.dashboard_outlined,
        selected: Icons.dashboard,
        label: l10n.navSessions,
      ),
      (
        icon: Icons.more_horiz_outlined,
        selected: Icons.more_horiz,
        label: l10n.navMore,
      ),
    ];

    final isWide = MediaQuery.sizeOf(context).width >= railBreakpoint;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: isWide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: _goBranch,
                    labelType: NavigationRailLabelType.all,
                    leading: const SizedBox(height: 8),
                    destinations: [
                      for (final destination in destinations)
                        NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selected),
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: navigationShell),
                ],
              )
            : navigationShell,
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goBranch,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selected),
                    label: destination.label,
                  ),
              ],
            ),
      floatingActionButton: const _TerminalSwitcherButton(),
    );
  }

  void _goBranch(int index) {
    // Tapping the current tab returns it to its root, which is the standard
    // affordance for backing out of a deep stack without repeated back taps.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// Floating shortcut back into the open terminals (SPEC 10.6).
///
/// Only appears when terminals exist. A terminal that is running but off-screen
/// is easy to forget, and hunting for it through the tab hierarchy is exactly
/// the friction this app is meant to remove.
class _TerminalSwitcherButton extends ConsumerWidget {
  const _TerminalSwitcherButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(terminalManagerProvider);
    if (manager.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final count = manager.length;

    return FloatingActionButton.extended(
      onPressed: () => context.push(Routes.terminal),
      icon: Badge(
        isLabelVisible: count > 1,
        label: Text('$count'),
        child: const Icon(Icons.terminal),
      ),
      label: Text(l10n.terminalTitle),
    );
  }
}

/// The "More" hub listing the secondary sections (SPEC 6).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final entries = [
      (
        icon: Icons.bolt_outlined,
        title: l10n.moreCommands,
        route: Routes.commands,
      ),
      (icon: Icons.key_outlined, title: l10n.moreKeys, route: Routes.keys),
      (
        icon: Icons.swap_horiz_outlined,
        title: l10n.moreForwarding,
        route: Routes.forwarding,
      ),
      (
        icon: Icons.settings_outlined,
        title: l10n.moreSettings,
        route: Routes.settings,
      ),
      (icon: Icons.info_outline, title: l10n.moreAbout, route: Routes.about),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMore),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.actionSearch,
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final entry in entries)
            ListTile(
              leading: Icon(entry.icon),
              title: Text(entry.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(entry.route),
            ),
        ],
      ),
    );
  }
}
