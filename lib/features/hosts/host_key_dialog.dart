import 'package:flutter/material.dart';

import '../../core/security/fingerprint.dart';
import '../../core/ssh/host_key_verifier.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/common.dart';

/// Trust-on-first-use prompt for an unknown host key (SPEC 9.2).
///
/// Deliberately not a yes/no toast. The fingerprint is shown in full, grouped
/// for legibility, alongside the exact command to run on the other machine to
/// compare it — because a user who cannot check the fingerprint is only
/// performing the ritual of verification.
class HostKeyTrustDialog extends StatelessWidget {
  const HostKeyTrustDialog({required this.request, super.key});

  final HostKeyPromptRequest request;

  /// Returns true when the user trusts the key.
  static Future<bool> show(
    BuildContext context,
    HostKeyPromptRequest request,
  ) async {
    final trusted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HostKeyTrustDialog(request: request),
    );
    return trusted ?? false;
  }

  /// The key-file suffix OpenSSH uses, derived from the key type.
  String get _keyFileType {
    final type = request.keyType.toLowerCase();
    if (type.contains('ed25519')) return 'ed25519';
    if (type.contains('ecdsa')) return 'ecdsa';
    if (type.contains('rsa')) return 'rsa';
    return type.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      icon: const Icon(Icons.gpp_maybe_outlined),
      title: Text(l10n.hostKeyTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.hostKeyBody(
              '${request.hostname}:${request.port}',
            )),
            const SizedBox(height: 16),
            _Label(text: l10n.hostKeyType),
            Text(request.keyType, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            _Label(text: l10n.hostKeyFingerprint),
            const SizedBox(height: 4),
            CodeBlock(
              text: Fingerprint.forDisplay(request.fingerprintSha256),
              emphasis: true,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.hostKeyHint(_keyFileType),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.actionTrust),
        ),
      ],
    );
  }
}

/// The blocking warning shown when a stored fingerprint no longer matches
/// (SPEC 9.2, 31).
///
/// There is no "connect anyway" button. Clearing the stored key is a separate,
/// deliberate act in Settings, which is what keeps a changed key from being
/// waved through on reflex.
class HostKeyChangedDialog extends StatelessWidget {
  const HostKeyChangedDialog({
    required this.hostname,
    required this.saved,
    required this.received,
    super.key,
  });

  final String hostname;
  final String saved;
  final String received;

  static Future<void> show(
    BuildContext context, {
    required String hostname,
    required String saved,
    required String received,
  }) =>
      showDialog<void>(
        context: context,
        builder: (context) => HostKeyChangedDialog(
          hostname: hostname,
          saved: saved,
          received: received,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
      title: Text(l10n.hostKeyChangedTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.hostKeyChangedBody),
            const SizedBox(height: 16),
            _Label(text: l10n.hostKeyChangedSaved),
            const SizedBox(height: 4),
            CodeBlock(text: saved),
            const SizedBox(height: 12),
            _Label(text: l10n.hostKeyChangedReceived),
            const SizedBox(height: 4),
            CodeBlock(text: received, emphasis: true),
            const SizedBox(height: 16),
            Text(
              l10n.hostKeyChangedBlocked,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }
}
