import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/theme/status_colors.dart';
import '../../shared/widgets/common.dart';
import '../commands/command_edit_screen.dart';
import '../terminal/terminal_session.dart';
import 'conversation_session.dart';

/// The composer stays above keyboard and system insets; the transcript scrolls
/// independently and follows output only while the reader is at the bottom.
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.session,
    required this.onTerminal,
  });
  final TerminalSession session;
  final VoidCallback onTerminal;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _follow = true;
  int? _historyIndex;
  String _savedDraft = '';
  Timer? _elapsed;
  ConversationSession get conversation => widget.session.conversation!;

  @override
  void initState() {
    super.initState();
    _input.text = conversation.draft;
    _input.addListener(_draftChanged);
    conversation.addListener(_changed);
    _scroll.addListener(_scrolled);
    _elapsed = Timer.periodic(const Duration(seconds: 1), (_) {
      if (conversation.active != null) _changed();
    });
  }

  void _draftChanged() => conversation.draft = _input.text;

  void _scrolled() {
    final follow = _scroll.position.extentAfter < 80;
    if (_follow != follow) setState(() => _follow = follow);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_follow) _latest();
  }

  void _latest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _edit(String command) {
    _input.value = TextEditingValue(
      text: command,
      selection: TextSelection.collapsed(offset: command.length),
    );
    _focus.requestFocus();
    setState(() {});
  }

  void _history(bool previous) {
    final commands = conversation.commands;
    if (commands.isEmpty) return;
    if (_historyIndex == null) _savedDraft = _input.text;
    final next = (_historyIndex ?? commands.length) + (previous ? -1 : 1);
    if (next >= commands.length) {
      _historyIndex = null;
      _edit(_savedDraft);
    } else {
      _historyIndex = next.clamp(0, commands.length - 1);
      _edit(commands[_historyIndex!].command);
    }
  }

  void _submit() {
    if (_input.value.composing.isValid && !_input.value.composing.isCollapsed) {
      return;
    }
    try {
      if (conversation.submit(_input.text)) {
        _input.clear();
        _historyIndex = null;
        _follow = true;
        _latest();
        _focus.requestFocus();
      }
    } on ArgumentError {
      showMessage(
        context,
        AppLocalizations.of(context).conversationInputLimit,
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _elapsed?.cancel();
    conversation.removeListener(_changed);
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        showMessage(context, AppLocalizations.of(context).conversationCopied);
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final active = conversation.active;
    final canSubmit = conversation.ready && widget.session.isLive;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 300 ||
            (constraints.maxHeight < 500 &&
                MediaQuery.textScalerOf(context).scale(16) > 24);
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter, control: true):
                _submit,
            const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                _submit,
          },
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      if (conversation.commands.isEmpty)
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.conversationTitle,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(l10n.conversationIntro),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 56),
                          itemCount: conversation.commands.length,
                          itemBuilder: (context, index) =>
                              _card(conversation.commands[index]),
                        ),
                      if (!_follow)
                        Positioned(
                          bottom: 8,
                          right: 16,
                          child: FilledButton.icon(
                            onPressed: _latest,
                            icon: const Icon(Icons.arrow_downward),
                            label: Text(l10n.conversationLatest),
                          ),
                        ),
                    ],
                  ),
                ),
                if (canSubmit && conversation.generation > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.conversationRestarted,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (!canSubmit)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            active != null
                                ? l10n.conversationRunningHint
                                : conversation.unavailable ||
                                      !widget.session.isLive
                                ? l10n.conversationUnavailable
                                : l10n.conversationConnecting,
                            maxLines: compact ? 1 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (active != null)
                          IconButton(
                            onPressed: conversation.interrupt,
                            tooltip: l10n.actionStop,
                            icon: const Icon(Icons.stop_circle_outlined),
                          ),
                        IconButton(
                          onPressed: widget.onTerminal,
                          tooltip: l10n.terminalTitle,
                          icon: const Icon(Icons.terminal),
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!compact)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: conversation.commands.isEmpty
                                      ? null
                                      : () => _history(true),
                                  tooltip: l10n.conversationPrevious,
                                  icon: const Icon(Icons.history),
                                ),
                                IconButton(
                                  onPressed: _historyIndex == null
                                      ? null
                                      : () => _history(false),
                                  tooltip: l10n.conversationNext,
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                                for (final symbol in ['/', '~', '|', '&', '-'])
                                  TextButton(
                                    onPressed: () {
                                      final selection = _input.selection;
                                      final start = selection.isValid
                                          ? selection.start
                                          : _input.text.length;
                                      final end = selection.isValid
                                          ? selection.end
                                          : start;
                                      final text = _input.text.replaceRange(
                                        start,
                                        end,
                                        symbol,
                                      );
                                      _input.value = TextEditingValue(
                                        text: text,
                                        selection: TextSelection.collapsed(
                                          offset: start + symbol.length,
                                        ),
                                      );
                                      _focus.requestFocus();
                                    },
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                    ),
                                    child: Text(symbol),
                                  ),
                                IconButton(
                                  onPressed: conversation.commands.isEmpty
                                      ? null
                                      : conversation.clear,
                                  tooltip: l10n.conversationClear,
                                  icon: const Icon(Icons.clear_all),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                focusNode: _focus,
                                minLines: 1,
                                maxLines: compact ? 1 : 4,
                                maxLength:
                                    ConversationSession.maxCommandCharacters,
                                maxLengthEnforcement:
                                    MaxLengthEnforcement.enforced,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                autocorrect: false,
                                enableSuggestions: false,
                                smartDashesType: SmartDashesType.disabled,
                                smartQuotesType: SmartQuotesType.disabled,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.conversationCommand,
                                  counterText: '',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _input,
                              builder: (context, value, _) => IconButton.filled(
                                onPressed:
                                    canSubmit && value.text.trim().isNotEmpty
                                    ? _submit
                                    : null,
                                tooltip: l10n.actionRun,
                                icon: const Icon(Icons.send),
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(ConversationCommand entry) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final running = entry.state == ConversationCommandState.running;
    final duration = (entry.completedAt ?? DateTime.now()).difference(
      entry.submittedAt,
    );
    final status = switch (entry.state) {
      ConversationCommandState.running => l10n.conversationRunning,
      ConversationCommandState.unknown => l10n.conversationUnknown,
      ConversationCommandState.interrupted => l10n.conversationInterrupted,
      ConversationCommandState.completed => l10n.conversationExit(
        entry.exitCode!,
      ),
    };
    final statusText = l10n.conversationStatus(
      status,
      (duration.inMilliseconds / 1000).toStringAsFixed(1),
    );
    // Colour encodes the shell result, never an application failure: exit 0
    // stays quiet, a failed command reads as a normal result, and a lost or
    // interrupted one is clearly neither (SPEC 37, design 4.4).
    final statusColor = switch (entry.state) {
      ConversationCommandState.running => context.statusColors.connecting,
      ConversationCommandState.interrupted ||
      ConversationCommandState.unknown =>
        context.statusColors.warning,
      ConversationCommandState.completed when (
        entry.exitCode ?? 0
      ) != 0 =>
        context.statusColors.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    label: l10n.conversationCommand,
                    child: SelectableText(
                      entry.command,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.conversationActions,
                  onSelected: (value) async {
                    switch (value) {
                      case 'copy':
                        await _copy(entry.command);
                      case 'edit':
                        _edit(entry.command);
                      case 'run':
                        conversation.submit(entry.command);
                      case 'save':
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CommandEditScreen(
                              initialHostId: widget.session.host.id,
                              initialProjectId: widget.session.project?.id,
                              initialCommand: entry.command,
                            ),
                          ),
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'copy', child: Text(l10n.actionCopy)),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l10n.conversationEdit),
                    ),
                    PopupMenuItem(
                      value: 'run',
                      enabled: conversation.ready,
                      child: Text(l10n.conversationRunAgain),
                    ),
                    PopupMenuItem(value: 'save', child: Text(l10n.actionSave)),
                  ],
                ),
              ],
            ),
            // A live region announces the transition to a screen reader;
            // the child text is excluded so it is read exactly once.
            Semantics(
              liveRegion: running,
              label: statusText,
              child: ExcludeSemantics(
                child: Text(
                  statusText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ),
            if (running)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: conversation.interrupt,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(l10n.actionStop),
                  ),
                  TextButton.icon(
                    onPressed: widget.onTerminal,
                    icon: const Icon(Icons.terminal),
                    label: Text(l10n.terminalTitle),
                  ),
                ],
              ),
            if (entry.interactive) Text(l10n.conversationInteractive),
            if (entry.truncated) Text(l10n.conversationTruncated),
            if (entry.output.isNotEmpty) ...[
              const Divider(),
              Semantics(
                label: l10n.conversationOutput,
                child: SelectableText(
                  entry.output,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    onPressed: () => _copy(entry.output),
                    tooltip: l10n.conversationCopyOutput,
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () {
                        final box = context.findRenderObject()! as RenderBox;
                        SharePlus.instance.share(
                          ShareParams(
                            text: entry.output,
                            sharePositionOrigin:
                                box.localToGlobal(Offset.zero) & box.size,
                          ),
                        );
                      },
                      tooltip: l10n.actionShare,
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onTerminal,
                    icon: const Icon(Icons.terminal),
                    label: Text(l10n.terminalTitle),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
