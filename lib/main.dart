import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/bootstrap.dart';
import 'core/security/redaction.dart';
import 'core/ssh/credential_resolver.dart';
import 'core/ssh/host_key_verifier.dart';
import 'features/hosts/host_key_dialog.dart';
import 'features/hosts/secret_prompt_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Storage opens before the first frame so the UI never renders against a
  // half-initialised database, and the saved theme is right from frame one
  // (SPEC 41).
  final services = await AppServices.start(
    promptForHostKey: _promptForHostKey,
    promptForSecret: _promptForSecret,
    promptForKeyboardInteractive: _promptForKeyboardInteractive,
  );

  runApp(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const RelayShellApp(),
    ),
  );
}

/// Shows the trust-on-first-use prompt (SPEC 9.2).
///
/// Refuses when no UI is available. A prompt that cannot be shown must not be
/// treated as consent — that would be exactly the silent acceptance SPEC 44.3
/// forbids.
Future<bool> _promptForHostKey(HostKeyPromptRequest request) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return false;
  return HostKeyTrustDialog.show(context, request);
}

Future<Sensitive<String>?> _promptForSecret(SecretPromptRequest request) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return null;
  return SecretPromptDialog.show(context, request);
}

Future<List<String>?> _promptForKeyboardInteractive(
  SSHUserInfoRequest request,
) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return null;
  return KeyboardInteractiveDialog.show(context, request);
}
