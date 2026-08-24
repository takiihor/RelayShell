import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/security/ssh_key_material.dart';
import '../../core/storage/secret_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';

/// Offers the ways to add a credential (SPEC 18.1).
Future<void> importOrGenerateKey(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(l10n.keysImport),
            onTap: () => Navigator.of(context).pop('import'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.keysGenerate),
            subtitle: Text(l10n.keyGenerateBody),
            onTap: () => Navigator.of(context).pop('generate'),
          ),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: Text(l10n.keysAddPassword),
            onTap: () => Navigator.of(context).pop('password'),
          ),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return;

  switch (choice) {
    case 'import':
      await importPrivateKey(context, ref);
    case 'generate':
      await generateKey(context, ref);
    case 'password':
      await savePassword(context, ref);
  }
}

/// Imports a private key from a file or pasted text (SPEC 18.1).
///
/// The key text is parsed to derive its public half and fingerprint, then
/// written straight to secure storage. Nothing but metadata reaches SQLite, and
/// the private key is never shown again after import (SPEC 18.1, 44.1).
Future<void> importPrivateKey(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  final pemText = await _obtainKeyText(context);
  if (pemText == null || !context.mounted) return;

  final material = ref.read(keyMaterialProvider);

  String? passphrase;
  KeyDescription? description;

  // Loop so a wrong passphrase can be corrected without restarting the import.
  while (true) {
    try {
      description = material.describe(pemText, passphrase: passphrase);
      break;
    } on KeyMaterialException catch (error) {
      if (!error.needsPassphrase) {
        if (context.mounted) showMessage(context, error.message, isError: true);
        return;
      }
      if (!context.mounted) return;
      final entered = await _askPassphrase(context, retry: passphrase != null);
      if (entered == null) return;
      passphrase = entered;
    }
  }

  if (!context.mounted) return;

  final name = await _askName(
    context,
    title: l10n.keysImport,
    initial: description.comment ?? 'SSH key',
  );
  if (name == null || !context.mounted) return;

  final requireBiometric = ref.read(preferencesProvider).credentialBiometricDefault;
  final id = const Uuid().v4();
  final now = DateTime.now();

  final secrets = ref.read(secretStoreProvider);
  await secrets.write(SecretKind.privateKey, id, pemText);
  if (passphrase != null) {
    await secrets.write(SecretKind.passphrase, id, passphrase);
  }

  await ref.read(credentialsRepositoryProvider).upsert(
        Credential(
          id: id,
          name: name,
          type: CredentialType.privateKey,
          publicKey: description.publicKey,
          keyType: description.keyType,
          fingerprintSha256: description.fingerprintSha256,
          hasPassphrase: description.isEncrypted,
          requireBiometric: requireBiometric,
          createdAt: now,
          updatedAt: now,
        ),
      );

  if (context.mounted) showMessage(context, l10n.keyPrivateHidden);
}

/// Generates an Ed25519 key and shows its public half for copying.
Future<void> generateKey(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  final name = await _askName(
    context,
    title: l10n.keyGenerateTitle,
    initial: 'Phone key',
  );
  if (name == null || !context.mounted) return;

  final generated = ref.read(keyMaterialProvider).generateEd25519(
        comment: name.replaceAll(RegExp(r'\s+'), '-').toLowerCase(),
      );

  final id = const Uuid().v4();
  final now = DateTime.now();

  await ref.read(secretStoreProvider).write(
        SecretKind.privateKey,
        id,
        generated.privateKeyPem,
      );

  await ref.read(credentialsRepositoryProvider).upsert(
        Credential(
          id: id,
          name: name,
          type: CredentialType.privateKey,
          publicKey: generated.description.publicKey,
          keyType: generated.description.keyType,
          fingerprintSha256: generated.description.fingerprintSha256,
          requireBiometric:
              ref.read(preferencesProvider).credentialBiometricDefault,
          createdAt: now,
          updatedAt: now,
        ),
      );

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.key_outlined),
      title: Text(l10n.keyGeneratedTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.keyGeneratedBody),
            const SizedBox(height: 12),
            CodeBlock(text: generated.description.publicKey, emphasis: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
        FilledButton.icon(
          onPressed: () async {
            await copyPublicKey(context, ref, generated.description.publicKey);
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text(l10n.actionCopy),
        ),
      ],
    ),
  );
}

/// Saves a password credential to secure storage.
Future<void> savePassword(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => const _PasswordCredentialDialog(),
  );
  if (result == null || !context.mounted) return;

  final id = const Uuid().v4();
  final now = DateTime.now();

  await ref.read(secretStoreProvider).write(SecretKind.password, id, result.$2);
  await ref.read(credentialsRepositoryProvider).upsert(
        Credential(
          id: id,
          name: result.$1,
          type: CredentialType.password,
          requireBiometric:
              ref.read(preferencesProvider).credentialBiometricDefault,
          createdAt: now,
          updatedAt: now,
        ),
      );

  if (context.mounted) showMessage(context, l10n.filesSaved);
}

/// Deletes a credential and its secret material together.
///
/// Both must go: leaving a key in the Keychain with no record pointing at it
/// means it can never be removed through the UI again.
Future<void> deleteCredential(
  BuildContext context,
  WidgetRef ref,
  Credential credential,
) async {
  final l10n = AppLocalizations.of(context);

  final usedBy = await ref
      .read(hostsRepositoryProvider)
      .usingCredential(credential.id);
  if (!context.mounted) return;

  final confirmed = await confirmDestructive(
    context,
    title: l10n.keyDeleteTitle,
    body: l10n.keyDeleteBody,
    extraDetail: usedBy.isEmpty
        ? null
        : usedBy.map((host) => host.name).join('\n'),
  );
  if (!confirmed) return;

  await ref.read(hostsRepositoryProvider).clearCredential(credential.id);
  await ref.read(secretStoreProvider).deleteCredential(credential.id);
  await ref.read(credentialsRepositoryProvider).delete(credential.id);
}

/// Copies a public key, clearing the clipboard afterwards if configured.
Future<void> copyPublicKey(
  BuildContext context,
  WidgetRef ref,
  String publicKey,
) async {
  final l10n = AppLocalizations.of(context);
  final preferences = ref.read(preferencesProvider);

  await ref.read(clipboardGuardProvider).copySensitive(
        publicKey,
        clearAfter: preferences.clearClipboardAfterSecrets
            ? Duration(seconds: preferences.clearClipboardSeconds)
            : Duration.zero,
      );

  if (context.mounted) showMessage(context, l10n.keyPublicKeyCopied);
}

/// Reads key text from a picked file, or from a paste dialog.
Future<String?> _obtainKeyText(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  final source = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(l10n.keyChooseFile),
            onTap: () => Navigator.of(context).pop('file'),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste_outlined),
            title: Text(l10n.keyPasteInstead),
            onTap: () => Navigator.of(context).pop('paste'),
          ),
        ],
      ),
    ),
  );

  if (source == null || !context.mounted) return null;

  if (source == 'file') {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    // Read through the picker rather than the path: on Android a SAF URI has
    // no readable filesystem path.
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (context) => const _PasteKeyDialog(),
  );
}

Future<String?> _askPassphrase(
  BuildContext context, {
  bool retry = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PassphraseDialog(retry: retry),
  );
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: title, initial: initial),
  );
}

class _PasteKeyDialog extends StatefulWidget {
  const _PasteKeyDialog();

  @override
  State<_PasteKeyDialog> createState() => _PasteKeyDialogState();
}

class _PasteKeyDialogState extends State<_PasteKeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller
      ..clear()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.keyPasteTitle),
      content: TextField(
        controller: _controller,
        maxLines: 8,
        minLines: 5,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: InputDecoration(hintText: l10n.keyPasteHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
          child: Text(l10n.actionImport),
        ),
      ],
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.retry});

  final bool retry;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller
      ..clear()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.keyFieldPassphrase),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.retry ? l10n.keyPassphraseWrong : l10n.keyPassphraseRequired,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.retry
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (value) => Navigator.of(context).pop(value),
            decoration: InputDecoration(labelText: l10n.keyFieldPassphrase),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.actionContinue),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.keyFieldName),
        onSubmitted: (value) {
          if (value.trim().isEmpty) return;
          Navigator.of(context).pop(value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _PasswordCredentialDialog extends StatefulWidget {
  const _PasswordCredentialDialog();

  @override
  State<_PasswordCredentialDialog> createState() =>
      _PasswordCredentialDialogState();
}

class _PasswordCredentialDialogState extends State<_PasswordCredentialDialog> {
  final _name = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _password
      ..clear()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.keysAddPassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.keyFieldName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l10n.keyFieldPassword),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty || _password.text.isEmpty) return;
            Navigator.of(context).pop((name, _password.text));
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
