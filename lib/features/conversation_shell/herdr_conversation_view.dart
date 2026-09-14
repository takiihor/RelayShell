import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../terminal/accessory_keyboard.dart';
import '../terminal/herdr_composer.dart';
import '../terminal/terminal_session.dart';

/// A native conversation surface for one explicitly selected Herdr terminal.
/// Output is a live screen snapshot, not invented agent message boundaries.
class HerdrConversationView extends StatefulWidget {
  const HerdrConversationView({super.key, required this.session});
  final TerminalSession session;

  @override
  State<HerdrConversationView> createState() => _HerdrConversationViewState();
}

class _HerdrConversationViewState extends State<HerdrConversationView> {
  final _scroll = ScrollController();
  Timer? _refresh;
  String _output = '';

  @override
  void initState() {
    super.initState();
    widget.session.terminal.addListener(_changed);
    widget.session.addListener(_changed);
    _output = _snapshot();
  }

  String _snapshot() {
    final lines = widget.session.terminal.buffer.lines;
    final start = (lines.length - 400).clamp(0, lines.length);
    final result = StringBuffer();
    for (var i = start; i < lines.length; i++) {
      if (i > start && !lines[i].isWrapped) result.write('\n');
      final line = lines[i].getText();
      final continues = i + 1 < lines.length && lines[i + 1].isWrapped;
      // Native frames pad rows to terminal width. Those blanks otherwise wrap
      // into empty lines in a narrow conversation card; keep code indentation.
      result.write(continues ? line : line.trimRight());
    }
    final text = result.toString().trimRight();
    if (text.length <= 32768) return text;
    var cut = text.length - 32768;
    if ((text.codeUnitAt(cut) & 0xfc00) == 0xdc00) cut++;
    return text.substring(cut);
  }

  void _changed() {
    _refresh ??= Timer(const Duration(milliseconds: 100), () {
      _refresh = null;
      if (!mounted) return;
      final follow = !_scroll.hasClients || _scroll.position.extentAfter < 80;
      setState(() => _output = _snapshot());
      if (follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    widget.session.terminal.removeListener(_changed);
    widget.session.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (!session.isLive)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.terminalDisconnected)),
                  if (session.canReconnect)
                    TextButton(
                      onPressed: () => unawaited(session.reconnect()),
                      child: Text(l10n.actionReconnect),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.herdrLiveOutput, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    _output.isEmpty ? l10n.herdrWaitingOutput : _output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AccessoryKeyboard(
            rows: const [
              ['esc', 'tab', 'up', 'down', 'left', 'right', 'enter'],
            ],
            haptics: session.preferences.hapticFeedback,
            modifiers: session.inputModifiers,
            safeAreaBottom: false,
            onSequence: (sequence) {
              if (session.isLive) session.sendRaw(sequence);
            },
          ),
          HerdrComposer(
            key: ValueKey(session.id),
            session: session,
            compact: constraints.maxHeight < 300,
          ),
        ],
      ),
    );
  }
}
