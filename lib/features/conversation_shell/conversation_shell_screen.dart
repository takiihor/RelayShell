import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/navigation/routes.dart';
import '../terminal/accessory_keyboard.dart';
import '../terminal/terminal_providers.dart';
import '../terminal/terminal_session.dart';
import 'conversation_controller.dart';
import 'conversation_models.dart';

/// Mobile-first command/output view over an existing live terminal PTY.
class ConversationShellScreen extends ConsumerStatefulWidget {
  const ConversationShellScreen({required this.sessionId, super.key});

  final String? sessionId;

  @override
  ConsumerState<ConversationShellScreen> createState() =>
      _ConversationShellScreenState();
}

class _ConversationShellScreenState
    extends ConsumerState<ConversationShellScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  ConversationController? _conversation;
  TerminalSession? _session;
  int? _historyIndex;
  String _historyDraft = '';
  TextEditingValue _lastInputValue = TextEditingValue.empty;
  bool _restoringInput = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    _lastInputValue = _input.value;
    _bindSession();
  }

  void _bindSession() {
    final manager = ref.read(terminalManagerProvider);
    final session = widget.sessionId == null
        ? manager.active
        : manager.byId(widget.sessionId!);
    _session = session;
    if (session == null) return;
    _conversation = ConversationController(session: session)
      ..addListener(_onConversationChanged);
  }

  void _onConversationChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  /// Mirrors Terminal Mode's modifier behavior for the phone keyboard.
  ///
  /// When an interactive process is running and CTRL/ALT/SHIFT is armed from
  /// the accessory row, the next single character typed on the soft keyboard
  /// is converted to the real terminal sequence and sent straight to the PTY.
  /// The character is removed from the composer, so CTRL then `b` really is
  /// Ctrl+B instead of the letter `b` appearing in the chat box.
  void _onInputChanged() {
    if (_restoringInput) return;

    final current = _input.value;
    final conversation = _conversation;
    final session = _session;
    if (conversation == null ||
        session == null ||
        !conversation.canSendProcessInput ||
        !session.inputModifiers.hasActiveModifier) {
      _lastInputValue = current;
      return;
    }

    final inserted = _singleInsertedRune(
      before: _lastInputValue.text,
      after: current.text,
    );
    if (inserted == null) {
      // IME commits and paste remain ordinary composer text and deliberately do
      // not consume an armed modifier, matching TerminalInputModifiers.
      _lastInputValue = current;
      return;
    }

    final sequence = session.inputModifiers.applyTerminalInput(inserted);
    conversation.sendRawToActive(sequence);
    _setInputValue(_lastInputValue);
  }

  static String? _singleInsertedRune({
    required String before,
    required String after,
  }) {
    if (after.length <= before.length) return null;

    var prefix = 0;
    final maxPrefix = before.length < after.length ? before.length : after.length;
    while (prefix < maxPrefix &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }

    var suffix = 0;
    while (suffix < before.length - prefix &&
        suffix < after.length - prefix &&
        before.codeUnitAt(before.length - 1 - suffix) ==
            after.codeUnitAt(after.length - 1 - suffix)) {
      suffix++;
    }

    final end = after.length - suffix;
    if (end < prefix) return null;
    final inserted = after.substring(prefix, end);
    return inserted.runes.length == 1 ? inserted : null;
  }

  void _setInputValue(TextEditingValue value) {
    _restoringInput = true;
    _input.value = value;
    _lastInputValue = value;
    _restoringInput = false;
  }

  @override
  void dispose() {
    _conversation?.removeListener(_onConversationChanged);
    _conversation?.dispose();
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    final conversation = _conversation;
    final preferences = ref.watch(preferencesProvider);

    if (session == null || conversation == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Icon(Icons.terminal_outlined, size: 40)),
      );
    }

    if (!conversation.supportsConversation) {
      return Scaffold(
        appBar: AppBar(title: Text(session.title)),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => _openTerminal(session),
            icon: const Icon(Icons.terminal),
            label: Text(l10n.computerOpenTerminal),
          ),
        ),
      );
    }

    final active = conversation.activeCommand;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.title),
            Text(
              session.subtitle,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openTerminal(session),
            icon: const Icon(Icons.terminal),
            tooltip: l10n.computerOpenTerminal,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: conversation.commands.isEmpty
                ? Center(
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 42,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: conversation.commands.length,
                    itemBuilder: (context, index) => _CommandExchange(
                      command: conversation.commands[index],
                      onStop: conversation.interrupt,
                      onOpenTerminal: () => _openTerminal(session),
                    ),
                  ),
          ),
          AccessoryKeyboard(
            rows: _conversationAccessoryRows(preferences.accessoryKeyRows),
            haptics: preferences.hapticFeedback,
            modifiers: session.inputModifiers,
            onSequence: _handleAccessorySequence,
            safeAreaBottom: false,
          ),
          _Composer(
            controller: _input,
            focusNode: _inputFocus,
            enabled: session.isLive,
            running: active != null,
            interactive: active?.interactiveHint == true,
            onSubmit: _submitOrSend,
            onStop: conversation.interrupt,
          ),
        ],
      ),
    );
  }

  /// Conversation keeps one compact horizontal row so the transcript remains
  /// useful above a phone keyboard. User custom keys are preserved, while the
  /// six coding-agent essentials are guaranteed even for older saved settings.
  static List<List<String>> _conversationAccessoryRows(
    List<List<String>> configured,
  ) {
    const essentials = ['esc', 'ctrl', 'shift', 'alt', 'tab', 'slash'];
    final seen = <String>{};
    final row = <String>[];

    void add(String key) {
      if (seen.add(key)) row.add(key);
    }

    for (final key in essentials) {
      add(key);
    }
    for (final configuredRow in configured) {
      for (final key in configuredRow) {
        add(key);
      }
    }
    return [row];
  }

  void _submitOrSend() {
    final conversation = _conversation;
    final session = _session;
    if (conversation == null || session == null || !session.isLive) return;
    final text = _input.text;
    if (text.trim().isEmpty) return;

    if (conversation.canSendProcessInput) {
      conversation.sendProcessInput(text);
    } else if (conversation.canSubmit) {
      conversation.submit(text);
      _historyIndex = null;
      _historyDraft = '';
    } else {
      return;
    }

    _setInputValue(TextEditingValue.empty);
    _inputFocus.requestFocus();
  }

  /// Accessory keys are context-sensitive without changing their terminal
  /// semantics. While Herdr/Codex/a TUI is running, exact bytes go to the live
  /// PTY. At a clean shell prompt, printable symbols edit the composer and the
  /// arrows provide mobile-friendly command history/cursor movement instead of
  /// bypassing Conversation framing.
  void _handleAccessorySequence(String sequence) {
    final conversation = _conversation;
    if (conversation == null) return;

    if (conversation.canSendProcessInput) {
      conversation.sendRawToActive(sequence);
      _inputFocus.requestFocus();
      return;
    }
    if (!conversation.canSubmit) return;

    switch (sequence) {
      case '\x1b[A':
        _historyPrevious();
      case '\x1b[B':
        _historyNext();
      case '\x1b[D':
        _moveComposerCursor(-1);
      case '\x1b[C':
        _moveComposerCursor(1);
      case '\x1b[H':
      case '\x01':
        _setComposerCursor(0);
      case '\x1b[F':
      case '\x05':
        _setComposerCursor(_input.text.length);
      case '\x1b':
        _inputFocus.unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      case '\t':
        _insertComposerText('\t');
      default:
        if (_isPrintable(sequence)) {
          _insertComposerText(sequence);
        }
    }
  }

  bool _isPrintable(String value) =>
      value.isNotEmpty &&
      !value.contains('\x1b') &&
      value.runes.every((rune) => rune == 0x09 || rune >= 0x20);

  void _insertComposerText(String value) {
    final text = _input.text;
    final selection = _input.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, value);
    final caret = start + value.length;
    _setInputValue(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: caret),
      ),
    );
    _inputFocus.requestFocus();
  }

  void _moveComposerCursor(int delta) {
    final selection = _input.selection;
    final current = selection.isValid ? selection.extentOffset : _input.text.length;
    final candidate = current + delta;
    final next = candidate < 0
        ? 0
        : candidate > _input.text.length
        ? _input.text.length
        : candidate;
    _setComposerCursor(next);
  }

  void _setComposerCursor(int offset) {
    _setInputValue(
      _input.value.copyWith(selection: TextSelection.collapsed(offset: offset)),
    );
    _inputFocus.requestFocus();
  }

  void _historyPrevious() {
    final commands = _conversation?.commands ?? const <ConversationCommand>[];
    if (commands.isEmpty) return;

    if (_historyIndex == null) {
      _historyDraft = _input.text;
      _historyIndex = commands.length - 1;
    } else if (_historyIndex! > 0) {
      _historyIndex = _historyIndex! - 1;
    }
    _replaceComposer(commands[_historyIndex!].command);
  }

  void _historyNext() {
    final commands = _conversation?.commands ?? const <ConversationCommand>[];
    final index = _historyIndex;
    if (index == null) return;
    if (index < commands.length - 1) {
      _historyIndex = index + 1;
      _replaceComposer(commands[_historyIndex!].command);
      return;
    }
    _historyIndex = null;
    _replaceComposer(_historyDraft);
  }

  void _replaceComposer(String value) {
    _setInputValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ),
    );
    _inputFocus.requestFocus();
  }

  void _openTerminal(TerminalSession session) {
    ref.read(terminalManagerProvider).setActive(session.id);
    context.push('${Routes.terminal}?session=${session.id}');
  }
}

class _CommandExchange extends StatelessWidget {
  const _CommandExchange({
    required this.command,
    required this.onStop,
    required this.onOpenTerminal,
  });

  final ConversationCommand command;
  final VoidCallback onStop;
  final VoidCallback onOpenTerminal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final duration = command.duration;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SelectableText(
                command.command,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (command.interactiveHint && command.isRunning)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.keyboard_alt_outlined, size: 16),
                      label: Text(l10n.commandModeInteractive),
                    ),
                  ),
                if (command.fullScreenDetected && command.isRunning) ...[
                  const SizedBox(height: 6),
                  FilledButton.tonalIcon(
                    onPressed: onOpenTerminal,
                    icon: const Icon(Icons.terminal, size: 18),
                    label: Text(l10n.commandOpenInTerminal),
                  ),
                  const SizedBox(height: 8),
                ],
                if (command.output.isNotEmpty)
                  SelectableText(
                    command.output.trimRight(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                for (final input in command.processInputs) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        input.text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                if (command.isRunning) ...[
                  if (command.output.isNotEmpty || command.processInputs.isNotEmpty)
                    const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onStop,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: Text(l10n.actionStop),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: onOpenTerminal,
                        icon: const Icon(Icons.terminal, size: 18),
                        label: Text(l10n.computerOpenTerminal),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (command.exitCode != null)
                        Text(
                          l10n.commandExitCode(command.exitCode!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: command.exitCode == 0
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.error,
                          ),
                        ),
                      if (duration != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(duration),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onOpenTerminal,
                        icon: const Icon(Icons.terminal, size: 18),
                        tooltip: l10n.computerOpenTerminal,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inSeconds < 1) return '${duration.inMilliseconds} ms';
    if (duration.inMinutes < 1) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes min $seconds s';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.running,
    required this.interactive,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool running;
  final bool interactive;
  final VoidCallback onSubmit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottom > 0 ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: running
                        ? interactive
                              ? l10n.commandModeInteractive
                              : l10n.commandRunning
                        : l10n.computerRunCommand,
                    prefixText: running ? '› ' : r'$ ',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (running) ...[
                IconButton.outlined(
                  onPressed: enabled ? onStop : null,
                  icon: const Icon(Icons.stop),
                  tooltip: l10n.actionStop,
                ),
                const SizedBox(width: 4),
              ],
              IconButton.filled(
                onPressed: enabled ? onSubmit : null,
                icon: const Icon(Icons.arrow_upward),
                tooltip: l10n.actionRun,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
