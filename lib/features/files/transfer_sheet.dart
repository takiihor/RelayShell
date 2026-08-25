import 'package:flutter/material.dart';

import '../../core/ssh/sftp_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utilities/formatting.dart';

/// Shows transfer progress with a working cancel (SPEC 15.4).
///
/// Returns true when the transfer completed, false when it was cancelled or
/// failed, so the caller knows whether to act on the result.
Future<bool> showTransferSheet(
  BuildContext context, {
  required String title,
  required TransferHandle handle,
}) async {
  final completed = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => _TransferSheet(title: title, handle: handle),
  );
  return completed ?? false;
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.title, required this.handle});

  final String title;
  final TransferHandle handle;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  TransferProgress? _progress;
  Object? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    widget.handle.progress.listen(
      (progress) {
        if (mounted) setState(() => _progress = progress);
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );

    widget.handle.completion.then(
      (_) {
        if (!mounted) return;
        setState(() => _finished = true);
        // Closing on success keeps the flow moving; a failure stays on screen
        // so the user can read what went wrong.
        Navigator.of(context).pop(true);
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = _progress;
    final error = _error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),

            if (error != null) ...[
              Text(
                error is FileOperationException
                    ? error.message
                    : l10n.filesTransferFailed,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionClose),
              ),
            ] else ...[
              LinearProgressIndicator(value: progress?.fraction),
              const SizedBox(height: 10),
              Text(
                progress == null
                    ? l10n.commandRunning
                    : l10n.filesTransferring(
                        formatBytes(progress.transferred),
                        formatBytes(progress.total),
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _finished
                    ? null
                    : () {
                        widget.handle.cancel();
                        Navigator.of(context).pop(false);
                      },
                child: Text(l10n.actionCancel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
