import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/security/app_lock.dart';
import '../../l10n/app_localizations.dart';

/// Opaque cover shown while the app is locked (SPEC 19).
///
/// Painted over the whole app rather than pushed as a route, so no screen —
/// including a terminal mid-session — can be behind it. The opaque background
/// is also what keeps terminal contents out of the OS app-switcher preview.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    // Prompt as soon as the lock appears; the user should not have to find a
    // button to get back into their own app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final lock = ref.read(appLockProvider);
    if (lock.state == AppLockState.authenticating) return;
    final unlocked = await lock.unlock();
    if (!mounted) return;
    setState(() => _attempted = !unlocked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lock = ref.watch(appLockProvider);

    return Material(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.lockTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _attempted ? l10n.lockFailed : l10n.lockBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _attempted
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (lock.state == AppLockState.authenticating)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.actionUnlock),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
