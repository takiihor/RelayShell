import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/security/fingerprint.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utilities/formatting.dart';
import '../../shared/widgets/common.dart';

/// The host fingerprints this device trusts (SPEC 21 Security).
///
/// Revoking is the deliberate, explicit escape hatch for a legitimately
/// rebuilt server — which is why it lives here rather than as a button on the
/// "identity changed" warning, where it would be tapped reflexively.
class TrustedKeysScreen extends ConsumerWidget {
  const TrustedKeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final keys = ref.watch(trustedKeysProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTrustedKeys)),
      body: keys.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.verified_user_outlined,
              title: l10n.settingsTrustedKeysCount(0),
              body: l10n.hostKeyBody(l10n.computersTitle),
            );
          }

          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final key = list[index];
              return ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(
                  key.endpointKey,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key.keyType,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      Fingerprint.forDisplay(key.fingerprintSha256),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      formatRelativeTime(l10n, key.trustedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.hostKeyForget,
                  onPressed: () async {
                    final confirmed = await confirmDestructive(
                      context,
                      title: l10n.hostKeyForget,
                      body: l10n.hostKeyForgetConfirm(key.endpointKey),
                      confirmLabel: l10n.hostKeyForget,
                    );
                    if (!confirmed) return;
                    await ref
                        .read(trustedKeysRepositoryProvider)
                        .revoke(key.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
