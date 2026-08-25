import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';

import '../../core/security/redaction.dart';
import '../../core/ssh/credential_resolver.dart';
import '../../l10n/app_localizations.dart';

/// Asks for a password or key passphrase during a connection attempt.
///
/// The value is returned wrapped in [Sensitive] and never stored by this
/// widget: the resolver hands it straight to the SSH client and drops it.
class SecretPromptDialog extends StatefulWidget {
  const SecretPromptDialog({required this.request, super.key});

  final SecretPromptRequest request;

  static Future<Sensitive<String>?> show(
    BuildContext context,
    SecretPromptRequest request,
  ) => showDialog<Sensitive<String>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SecretPromptDialog(request: request),
  );

  @override
  State<SecretPromptDialog> createState() => _SecretPromptDialogState();
}

class _SecretPromptDialogState extends State<SecretPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscured = true;

  @override
  void dispose() {
    // Clearing the controller drops the only copy this widget held.
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value.isEmpty) return;
    Navigator.of(context).pop(Sensitive(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPassphrase = widget.request.kind == SecretPromptKind.passphrase;

    final title = isPassphrase
        ? l10n.keyFieldPassphrase
        : l10n.keyFieldPassword;
    final subtitle = widget.request.credentialName == null
        ? widget.request.hostName
        : '${widget.request.credentialName} · ${widget.request.hostName}';

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.request.retry) ...[
            const SizedBox(height: 8),
            Text(
              l10n.keyPassphraseWrong,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscured,
            // Never offer autofill or suggestions for SSH secrets.
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: title,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionContinue)),
      ],
    );
  }
}

/// Answers a server's keyboard-interactive challenge (SPEC 8.2).
///
/// The prompts come from the server, so they are rendered as given rather than
/// translated — a 2FA challenge that says "Duo passcode:" must not be reworded.
class KeyboardInteractiveDialog extends StatefulWidget {
  const KeyboardInteractiveDialog({required this.request, super.key});

  final SSHUserInfoRequest request;

  static Future<List<String>?> show(
    BuildContext context,
    SSHUserInfoRequest request,
  ) => showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => KeyboardInteractiveDialog(request: request),
  );

  @override
  State<KeyboardInteractiveDialog> createState() =>
      _KeyboardInteractiveDialogState();
}

class _KeyboardInteractiveDialogState extends State<KeyboardInteractiveDialog> {
  late final List<TextEditingController> _controllers = List.generate(
    widget.request.prompts.length,
    (_) => TextEditingController(),
  );

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..clear()
        ..dispose();
    }
    super.dispose();
  }

  void _submit() {
    Navigator.of(context)
        .pop(_controllers.map((controller) => controller.text).toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = widget.request.name.trim();
    final instruction = widget.request.instruction.trim();

    return AlertDialog(
      title: Text(name.isEmpty ? l10n.authMethodKeyboardInteractive : name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (instruction.isNotEmpty) ...[
              Text(instruction, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],
            for (var i = 0; i < widget.request.prompts.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              TextField(
                controller: _controllers[i],
                autofocus: i == 0,
                // The server states whether each answer should be visible.
                obscureText: !widget.request.prompts[i].echo,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) {
                  if (i == widget.request.prompts.length - 1) _submit();
                },
                decoration: InputDecoration(
                  labelText: widget.request.prompts[i].promptText.trim(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionContinue)),
      ],
    );
  }
}
