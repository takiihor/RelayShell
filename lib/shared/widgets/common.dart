import 'package:flutter/material.dart';

import '../../core/ssh/ssh_failure.dart';
import '../../l10n/app_localizations.dart';

/// The empty state every major screen must have (SPEC 32).
///
/// Always offers the one action that resolves the emptiness, because a screen
/// that only explains why it is blank leaves the user hunting for the button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 8, 8),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Presents an [SshFailure] the way SPEC 31 requires: a plain-language message
/// and a next step first, with the raw exception behind an expander.
class FailureView extends StatelessWidget {
  const FailureView({
    required this.failure,
    super.key,
    this.onRetry,
    this.retryLabel,
    this.secondaryLabel,
    this.onSecondary,
  });

  final SshFailure failure;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              failure.message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (failure.action != null) ...[
              const SizedBox(height: 8),
              Text(
                failure.action!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            if (onRetry != null)
              FilledButton(
                onPressed: onRetry,
                child: Text(retryLabel ?? l10n.actionRetry),
              ),
            if (onSecondary != null && secondaryLabel != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
            if (failure.technicalDetail != null) ...[
              const SizedBox(height: 12),
              TechnicalDetails(detail: failure.technicalDetail!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Collapsed raw error text (SPEC 31: available, never the primary message).
class TechnicalDetails extends StatelessWidget {
  const TechnicalDetails({required this.detail, super.key});

  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          l10n.actionShowDetails,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A centred progress indicator with an optional caption.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A monospace, selectable block for fingerprints, commands and public keys.
class CodeBlock extends StatelessWidget {
  const CodeBlock({
    required this.text,
    super.key,
    this.maxLines,
    this.emphasis = false,
  });

  final String text;
  final int? maxLines;

  /// Draws attention, for things the user is being asked to verify.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasis
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: SelectableText(
        text,
        maxLines: maxLines,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          height: 1.4,
          color: emphasis
              ? theme.colorScheme.onSecondaryContainer
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Asks the user to confirm a destructive action (SPEC 15.2, 13.3).
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
  String? extraDetail,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (extraDetail != null) ...[
            const SizedBox(height: 12),
            CodeBlock(text: extraDetail, maxLines: 6),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? l10n.confirmDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shows a transient message. Centralised so every screen reports the same way.
void showMessage(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.errorContainer : null,
      ),
    );
}

/// Reports a failure as a snack bar, keeping the actionable phrasing.
void showFailure(BuildContext context, Object error) {
  final message = switch (error) {
    SshFailure failure => failure.action == null
        ? failure.message
        : '${failure.message} ${failure.action}',
    _ => error.toString(),
  };
  showMessage(context, message, isError: true);
}
