import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/security/fingerprint.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import 'key_actions.dart';

/// Credential management (SPEC 18).
class KeysScreen extends ConsumerWidget {
  const KeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final credentials = ref.watch(credentialsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.keysTitle)),
      floatingActionButton: credentials.value?.isEmpty ?? true
          ? null
          : FloatingActionButton(
              heroTag: 'add-key',
              onPressed: () => importOrGenerateKey(context, ref),
              child: const Icon(Icons.add),
            ),
      body: credentials.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.key_outlined,
              title: l10n.keysEmptyTitle,
              body: l10n.keysEmptyBody,
              actionLabel: l10n.keysImport,
              onAction: () => importOrGenerateKey(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _CredentialTile(credential: list[index]),
          );
        },
      ),
    );
  }
}

class _CredentialTile extends ConsumerWidget {
  const _CredentialTile({required this.credential});

  final Credential credential;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                credential.isKey ? Icons.key_outlined : Icons.password_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(credential.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      credential.keyType ?? l10n.authMethodPassword,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (credential.requireBiometric)
                Icon(
                  Icons.fingerprint,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              if (credential.hasPassphrase) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CredentialSheet(credential: credential),
    );
  }
}

class _CredentialSheet extends ConsumerWidget {
  const _CredentialSheet({required this.credential});

  final Credential credential;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hostsUsing = ref.watch(hostsProvider).value ?? const [];
    final usageCount = hostsUsing
        .where((host) => host.credentialId == credential.id)
        .length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(credential.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.keyUsedBy(usageCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              if (credential.keyType != null) ...[
                _DetailRow(label: l10n.keyType, value: credential.keyType!),
                const SizedBox(height: 12),
              ],
              if (credential.fingerprintSha256 != null) ...[
                Text(l10n.keyFingerprint, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                CodeBlock(
                  text: Fingerprint.forDisplay(credential.fingerprintSha256!),
                ),
                const SizedBox(height: 12),
              ],
              if (credential.publicKey != null) ...[
                Text(l10n.keyPublicKey, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                CodeBlock(text: credential.publicKey!, maxLines: 4),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      copyPublicKey(context, ref, credential.publicKey!),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.keyCopyPublicKey),
                ),
                const SizedBox(height: 12),
              ],

              // The private half is never shown again after import (SPEC 18.1).
              Text(
                l10n.keyPrivateHidden,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: credential.requireBiometric,
                title: Text(l10n.keyRequireBiometric),
                subtitle: Text(l10n.keyRequireBiometricHelp),
                onChanged: (value) async {
                  final available = await ref
                      .read(appServicesProvider)
                      .biometrics
                      .isAvailable;
                  if (!context.mounted) return;
                  if (value && !available) {
                    showMessage(
                      context,
                      l10n.settingsAppLockHelp,
                      isError: true,
                    );
                    return;
                  }
                  await ref
                      .read(credentialsRepositoryProvider)
                      .upsert(credential.copyWith(requireBiometric: value));
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await deleteCredential(context, ref, credential);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.actionDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
