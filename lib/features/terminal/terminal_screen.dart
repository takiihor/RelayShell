import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/terminal_themes.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import 'accessory_keyboard.dart';
import 'terminal_providers.dart';
import 'terminal_session.dart';

/// The interactive terminal (SPEC 10).
///
/// Full-screen and outside the tab shell, because a terminal competing with app
/// navigation for the same screen edge loses rows the user needs (SPEC 39).
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _wakeLockHeld = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final id = widget.sessionId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(terminalManagerProvider).setActive(id);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWakeLock());
  }

  /// Holds the wake lock only while a terminal is actually on screen.
  Future<void> _syncWakeLock() async {
    final wanted = ref.read(preferencesProvider).keepScreenAwake;
    if (wanted == _wakeLockHeld) return;
    final wakeLock = ref.read(wakeLockProvider);
    if (wanted) {
      await wakeLock.acquire();
    } else {
      await wakeLock.release();
    }
    _wakeLockHeld = wanted;
  }

  @override
  void dispose() {
    if (_wakeLockHeld) {
      // Released rather than awaited: the widget is going away either way, and
      // leaving the screen pinned awake would outlive the reason for it.
      ref.read(wakeLockProvider).release();
    }
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final manager = ref.watch(terminalManagerProvider);
    final preferences = ref.watch(preferencesProvider);

    final session = widget.sessionId == null
        ? manager.active
        : manager.byId(widget.sessionId!) ?? manager.active;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.terminalTitle)),
        body: EmptyState(
          icon: Icons.terminal,
          title: l10n.terminalNoTabs,
          body: l10n.sessionsEmptyBody,
          actionLabel: l10n.navComputers,
          onAction: () => context.go(Routes.hosts),
        ),
      );
    }

    final namedTheme = TerminalThemeCatalog.byId(preferences.terminalThemeId);

    return Scaffold(
      backgroundColor: namedTheme.theme.background,
      appBar: _TerminalAppBar(
        session: session,
        onSearch: () => setState(() => _searching = !_searching),
        searching: _searching,
      ),
      body: Column(
        children: [
          if (session.state == TerminalSessionState.disconnected ||
              session.state == TerminalSessionState.failed)
            _DisconnectedBanner(session: session),
          if (_searching)
            _TerminalSearchBar(
              session: session,
              scrollController: _scrollController,
              lineHeight: _lineHeightFor(preferences),
              onClose: () => setState(() => _searching = false),
            ),
          Expanded(
            child: TerminalView(
              session.terminal,
              controller: session.controller,
              scrollController: _scrollController,
              focusNode: _focusNode,
              autofocus: true,
              theme: namedTheme.theme,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              textStyle: TerminalStyle(
                fontSize: preferences.terminalFontSize,
                fontFamily: preferences.terminalFontFamily,
                fontFamilyFallback: TerminalFonts.fallbacks,
              ),
              cursorType: switch (preferences.cursorStyle) {
                TerminalCursorStyle.block => TerminalCursorType.block,
                TerminalCursorStyle.underline => TerminalCursorType.underline,
                TerminalCursorStyle.bar => TerminalCursorType.verticalBar,
              },
              // Mobile IMEs often do not emit a hardware delete event, so the
              // workaround is on by default here (SPEC 10.1).
              deleteDetection: true,
              onSecondaryTapDown: (details, offset) =>
                  _showSelectionMenu(context, session),
              readOnly: !session.isLive,
            ),
          ),
          AccessoryKeyboard(
            rows: preferences.accessoryKeyRows,
            haptics: preferences.hapticFeedback,
            modifiers: session.inputModifiers,
            onSequence: session.sendRaw,
          ),
        ],
      ),
    );
  }

  /// Height of one terminal row, in logical pixels.
  ///
  /// Measured the same way the renderer does — laying out a monospace run with
  /// the active style — so a search jump lands on the row the user is looking
  /// for rather than a few lines off.
  double _lineHeightFor(AppPreferences preferences) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'M',
        style: TextStyle(
          fontSize: preferences.terminalFontSize,
          height: 1.2,
          fontFamily: preferences.terminalFontFamily,
          fontFamilyFallback: TerminalFonts.fallbacks,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  Future<void> _showSelectionMenu(
    BuildContext context,
    TerminalSession session,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selection = session.selectedText();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selection != null)
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.terminalCopySelection),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: selection));
                  session.clearSelection();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(l10n.terminalPaste),
              onTap: () async {
                Navigator.of(context).pop();
                await _paste(session);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pastes, confirming first for multi-line text (SPEC 21 Terminal).
  ///
  /// A pasted newline executes immediately; confirming is the difference
  /// between reviewing a script and running it by accident.
  Future<void> _paste(TerminalSession session) async {
    final l10n = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;

    final lineCount = '\n'.allMatches(text).length + 1;
    final needsConfirm =
        ref.read(preferencesProvider).confirmMultilinePaste && lineCount > 1;

    if (needsConfirm) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.terminalPasteConfirmTitle(lineCount)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.terminalPasteConfirmBody),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(child: CodeBlock(text: text)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.terminalPaste),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    session.paste(text);
  }
}

class _TerminalAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TerminalAppBar({
    required this.session,
    required this.onSearch,
    required this.searching,
  });

  final TerminalSession session;
  final VoidCallback onSearch;
  final bool searching;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final manager = ref.watch(terminalManagerProvider);

    return AppBar(
      title: InkWell(
        onTap: manager.length > 1 ? () => _showSwitcher(context, ref) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.title,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    session.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (manager.length > 1) const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(searching ? Icons.search_off : Icons.search),
          tooltip: l10n.terminalSearch,
          onPressed: onSearch,
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _onMenu(context, ref, value),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'info', child: Text(l10n.terminalSessionInfo)),
            PopupMenuItem(
              value: 'reconnect',
              child: Text(l10n.actionReconnect),
            ),
            PopupMenuItem(value: 'send', child: Text(l10n.terminalSendCommand)),
            PopupMenuItem(
              value: 'files',
              child: Text(l10n.terminalOpenFilesHere),
            ),
            PopupMenuItem(value: 'font', child: Text(l10n.terminalFontSize)),
            if (session.isPersistent)
              PopupMenuItem(
                value: 'detach',
                child: Text(l10n.sessionModePersistent),
              ),
            PopupMenuItem(value: 'close', child: Text(l10n.actionDisconnect)),
          ],
        ),
      ],
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final l10n = AppLocalizations.of(context);

    switch (value) {
      case 'info':
        await _showSessionInfo(context, ref);
      case 'reconnect':
        await session.reconnect();
      case 'send':
        final command = await _askCommand(context);
        if (command != null) session.sendText(command);
      case 'files':
        final path = session.launchPlan.workingDirectory;
        context.push(
          '${Routes.files(session.host.id)}'
          '${path == null ? '' : '?path=${Uri.encodeComponent(path)}'}',
        );
      case 'font':
        await _showFontSizeSheet(context, ref);
      case 'detach':
        // Detaching leaves the tmux session running on the computer, which is
        // the whole point of a persistent session.
        session.detachTmux();
        if (context.mounted) {
          showMessage(context, l10n.sessionModePersistentHelp);
        }
      case 'close':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l10n.terminalCloseTabConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.actionClose),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await ref.read(terminalManagerProvider).close(session.id);
        if (context.mounted) context.pop();
    }
  }

  Future<void> _showSessionInfo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.terminalSessionInfo,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _InfoRow(label: l10n.computerFieldName, value: session.host.name),
              _InfoRow(
                label: l10n.computerFieldHostname,
                value: session.host.displaySubtitle,
              ),
              if (session.tmuxSessionName != null)
                _InfoRow(label: 'tmux', value: session.tmuxSessionName!),
              if (session.launchPlan.workingDirectory != null)
                _InfoRow(
                  label: l10n.commandFieldWorkingDirectory,
                  value: session.launchPlan.workingDirectory!,
                ),
              _InfoRow(
                label: l10n.settingsTerminalType,
                value: session.preferences.terminalType,
              ),
              if (session.exitCode != null)
                _InfoRow(
                  label: l10n.commandExitCode(session.exitCode!),
                  value: '',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFontSizeSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _FontSizeSheet(),
    );
  }

  Future<void> _showSwitcher(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final manager = ref.read(terminalManagerProvider);

    await showModalBottomSheet<void>(
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
                l10n.terminalTabs,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final tab in manager.tabs)
              ListTile(
                selected: tab.id == session.id,
                leading: Icon(
                  tab.isPersistent ? Icons.play_circle_outline : Icons.terminal,
                ),
                title: Text(tab.title),
                subtitle: Text(tab.subtitle),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.terminalCloseTab,
                  onPressed: () async {
                    await manager.close(tab.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  manager.setActive(tab.id);
                  Navigator.of(context).pop();
                  context.pushReplacement(
                    '${Routes.terminal}?session=${tab.id}',
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askCommand(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.terminalSendCommand),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'monospace'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.actionRun),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeSheet extends ConsumerWidget {
  const _FontSizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preferences = ref.watch(preferencesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.terminalFontSize,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: preferences.terminalFontSize,
              min: TerminalFonts.minSize,
              max: TerminalFonts.maxSize,
              divisions: (TerminalFonts.maxSize - TerminalFonts.minSize)
                  .round(),
              label: preferences.terminalFontSize.toStringAsFixed(0),
              onChanged: (value) => ref
                  .read(preferencesProvider.notifier)
                  .edit((current) => current.copyWith(terminalFontSize: value)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisconnectedBanner extends ConsumerWidget {
  const _DisconnectedBanner({required this.session});

  final TerminalSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final failure = session.failure;

    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              Icons.link_off,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                failure?.message ?? l10n.terminalDisconnected,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: session.reconnect,
              child: Text(l10n.actionReconnect),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searches the visible buffer and scrollback (SPEC 10.1).
class _TerminalSearchBar extends StatefulWidget {
  const _TerminalSearchBar({
    required this.session,
    required this.scrollController,
    required this.lineHeight,
    required this.onClose,
  });

  final TerminalSession session;
  final ScrollController scrollController;
  final double lineHeight;
  final VoidCallback onClose;

  @override
  State<_TerminalSearchBar> createState() => _TerminalSearchBarState();
}

class _TerminalSearchBarState extends State<_TerminalSearchBar> {
  final TextEditingController _controller = TextEditingController();
  List<int> _matches = const [];
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scans buffer lines for [query], newest content last.
  void _search(String query) {
    if (query.isEmpty) {
      setState(() {
        _matches = const [];
        _index = 0;
      });
      return;
    }

    final buffer = widget.session.terminal.buffer;
    final needle = query.toLowerCase();
    final found = <int>[];

    for (var line = 0; line < buffer.lines.length; line++) {
      final text = buffer.lines[line].toString().toLowerCase();
      if (text.contains(needle)) found.add(line);
    }

    setState(() {
      _matches = found;
      _index = found.isEmpty ? 0 : 0;
    });
    _scrollToMatch();
  }

  /// Scrolls the terminal so the current match sits near the top.
  ///
  /// Leaving the hit at the top keeps the lines *after* it visible, which is
  /// what a log search is usually looking for.
  void _scrollToMatch() {
    if (_matches.isEmpty || !widget.scrollController.hasClients) return;
    final target = _matches[_index] * widget.lineHeight;
    final position = widget.scrollController.position;
    widget.scrollController.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  void _step(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _index = (_index + delta) % _matches.length;
      if (_index < 0) _index += _matches.length;
    });
    _scrollToMatch();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.terminalSearchHint,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onChanged: _search,
                onSubmitted: (_) => _step(1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _matches.isEmpty
                  ? l10n.terminalSearchNoResults
                  : l10n.terminalSearchResult(_index + 1, _matches.length),
              style: theme.textTheme.bodySmall,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: _matches.isEmpty ? null : () => _step(-1),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: _matches.isEmpty ? null : () => _step(1),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}
