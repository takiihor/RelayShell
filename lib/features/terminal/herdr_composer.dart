import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/common.dart';
import 'terminal_session.dart';

class HerdrComposer extends StatefulWidget {
  const HerdrComposer({super.key, required this.session});
  final TerminalSession session;
  @override
  State<HerdrComposer> createState() => _HerdrComposerState();
}

class _HerdrComposerState extends State<HerdrComposer> {
  late final TextEditingController _text = TextEditingController(
    text: widget.session.paneDraft,
  );
  final _focus = FocusNode();
  bool _sending = false;
  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      widget.session.paneDraft = _text.text;
    });
  }

  Future<void> _send() async {
    if (_sending ||
        !widget.session.isLive ||
        _text.text.trim().isEmpty ||
        _text.value.composing.isValid && !_text.value.composing.isCollapsed) {
      return;
    }
    final text = _text.text;
    setState(() => _sending = true);
    try {
      await widget.session.submitPane(text);
      if (!mounted) return;
      if (_text.text == text) _text.clear();
      _focus.requestFocus();
      showMessage(context, AppLocalizations.of(context).herdrSent);
    } catch (_) {
      // Failure may occur after delivery. Preserve the draft; never replay it.
      if (mounted) {
        showMessage(
          context,
          AppLocalizations.of(context).herdrDeliveryUnknown,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = widget.session;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  _send,
              const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                  _send,
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: session.isLive
                          ? () => session.scrollHerdr(true)
                          : null,
                      tooltip: l10n.herdrScrollUp,
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    IconButton(
                      onPressed: session.isLive
                          ? () => session.scrollHerdr(false)
                          : null,
                      tooltip: l10n.herdrScrollDown,
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: session.isLive
                          ? () => session.sendRaw('\x03')
                          : null,
                      tooltip: l10n.actionStop,
                      icon: const Icon(Icons.stop_circle_outlined),
                    ),
                    IconButton(
                      onPressed: session.isLive
                          ? () => session.sendRaw('\x1b')
                          : null,
                      tooltip: l10n.herdrEscape,
                      icon: const Icon(Icons.keyboard_return),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: MediaQuery.sizeOf(context).height < 500
                            ? 1
                            : 3,
                        maxLength: 16384,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        autocorrect: false,
                        enableSuggestions: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.herdrCompose,
                          counterText: '',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder(
                      valueListenable: _text,
                      builder: (context, value, _) => IconButton.filled(
                        onPressed:
                            session.isLive &&
                                !_sending &&
                                value.text.trim().isNotEmpty
                            ? _send
                            : null,
                        tooltip: l10n.herdrSend,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
