import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/navigation/routes.dart';
import '../../shared/widgets/common.dart';
import '../keys/key_actions.dart';

/// The short setup flow for a computer reached over SSH or Tailscale.
class HostEditScreen extends ConsumerStatefulWidget {
  const HostEditScreen({super.key, this.hostId});

  final String? hostId;

  @override
  ConsumerState<HostEditScreen> createState() => _HostEditScreenState();
}

class _HostEditScreenState extends ConsumerState<HostEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _hostname = TextEditingController();
  final _username = TextEditingController();
  final _port = TextEditingController(text: '${Host.defaultPort}');
  final _startupDirectory = TextEditingController();

  AuthMethod _authMethod = AuthMethod.privateKey;
  String? _credentialId;
  Host? _existing;
  bool _loaded = false;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;
  bool _testSucceeded = false;

  bool get _isNew => widget.hostId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final host = await ref.read(hostsRepositoryProvider).byId(widget.hostId!);
    if (!mounted || host == null) {
      setState(() => _loaded = true);
      return;
    }

    setState(() {
      _existing = host;
      _name.text = host.name;
      _hostname.text = host.hostname;
      _username.text = host.username;
      _port.text = '${host.port}';
      _startupDirectory.text = host.startupDirectory ?? '';
      _authMethod = host.authMethod;
      _credentialId = host.credentialId;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _hostname.dispose();
    _username.dispose();
    _port.dispose();
    _startupDirectory.dispose();
    super.dispose();
  }

  String get _connectionName {
    final entered = _name.text.trim();
    return entered.isEmpty ? _hostname.text.trim() : entered;
  }

  Host _buildHost() {
    final now = DateTime.now();
    final existing = _existing;
    final port = int.parse(_port.text.trim());

    if (existing != null) {
      return existing.copyWith(
        name: _connectionName,
        hostname: _hostname.text.trim(),
        port: port,
        username: _username.text.trim(),
        authMethod: _authMethod,
        credentialId: _credentialId,
        startupDirectory: _emptyToNull(_startupDirectory.text),
        updatedAt: now,
      );
    }

    return Host(
      id: const Uuid().v4(),
      name: _connectionName,
      hostname: _hostname.text.trim(),
      port: port,
      username: _username.text.trim(),
      authMethod: _authMethod,
      credentialId: _credentialId,
      platform: RemotePlatform.posix,
      multiplexer: MultiplexerKind.tmux,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _test() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final host = _buildHost();
    // A saved computer can already have an interactive terminal using its
    // shared transport. Give this probe its own transient identity so a test
    // neither reuses nor disconnects the user's live shell.
    final testHost = Host(
      id: const Uuid().v4(),
      name: host.name,
      hostname: host.hostname,
      port: host.port,
      username: host.username,
      authMethod: host.authMethod,
      credentialId: host.credentialId,
      platform: host.platform,
      multiplexer: host.multiplexer,
      createdAt: host.createdAt,
      updatedAt: host.updatedAt,
    );
    final connections = ref.read(connectionManagerProvider);
    final l10n = AppLocalizations.of(context);
    try {
      final connection = await connections.connect(testHost);
      if (!mounted) return;
      setState(() {
        _testSucceeded = connection.host.id == testHost.id;
        _testResult = l10n.testConnectionSuccess;
      });
    } on SshFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _testSucceeded = false;
        _testResult = failure.action == null
            ? failure.message
            : '${failure.message}\n${failure.action}';
      });
    } finally {
      // Closing this short-lived probe must never block the result or touch a
      // live terminal connection for the saved computer.
      unawaited(connections.disconnect(testHost.id));
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final host = _buildHost();
    final previous = _existing;
    if (previous != null &&
        (previous.hostname != host.hostname || previous.port != host.port)) {
      await ref
          .read(trustedKeysRepositoryProvider)
          .revokeEndpoint(hostname: previous.hostname, port: previous.port);
      await ref.read(connectionManagerProvider).disconnect(host.id);
    }

    await ref.read(hostsRepositoryProvider).upsert(host);
    await ref
        .read(trustedKeysRepositoryProvider)
        .attachUnownedEndpoint(
          hostId: host.id,
          hostname: host.hostname,
          port: host.port,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final credentials = ref.watch(credentialsProvider).value ?? const [];

    if (!_loaded) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.computerNew : l10n.computerEdit),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(l10n.actionSave),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
          children: [
            Text(l10n.connectionSetupTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              l10n.connectionSetupBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.computerFieldName,
                hintText: l10n.computerFieldNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hostname,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.computerFieldHostname,
                hintText: l10n.computerFieldHostnameHint,
              ),
              validator: _required(l10n),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.computerFieldUsername,
              ),
              validator: _required(l10n),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.computerSectionAuthentication,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AuthMethod>(
              initialValue: _authMethod,
              decoration: InputDecoration(labelText: l10n.authSelectCredential),
              items: [
                DropdownMenuItem(
                  value: AuthMethod.privateKey,
                  child: Text(l10n.authMethodPrivateKey),
                ),
                DropdownMenuItem(
                  value: AuthMethod.password,
                  child: Text(l10n.authMethodPassword),
                ),
                DropdownMenuItem(
                  value: AuthMethod.keyboardInteractive,
                  child: Text(l10n.authMethodKeyboardInteractive),
                ),
              ],
              onChanged: (value) => setState(() {
                _authMethod = value ?? AuthMethod.privateKey;
                _credentialId = null;
              }),
            ),
            if (_authMethod == AuthMethod.privateKey) ...[
              const SizedBox(height: 8),
              Text(
                l10n.authMethodRecommendation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_authMethod == AuthMethod.privateKey ||
                _authMethod == AuthMethod.password) ...[
              const SizedBox(height: 12),
              _CredentialPicker(
                credentials: credentials
                    .where(
                      (credential) => _authMethod == AuthMethod.privateKey
                          ? credential.type == CredentialType.privateKey
                          : credential.type == CredentialType.password,
                    )
                    .toList(),
                selectedId: _credentialId,
                allowNone: _authMethod == AuthMethod.password,
                onChanged: (id) => setState(() => _credentialId = id),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_outlined),
              label: Text(
                _testing ? l10n.testConnectionRunning : l10n.actionTest,
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              _TestResult(success: _testSucceeded, text: _testResult!),
            ],
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.computerAdvanced),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.computerFieldPort,
                    ),
                    validator: (value) {
                      final port = int.tryParse(value?.trim() ?? '');
                      if (port == null || port < 1 || port > 65535) {
                        return l10n.errorInvalidPort;
                      }
                      return null;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _startupDirectory,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: l10n.computerFieldStartupDirectory,
                      helperText: l10n.computerFieldStartupDirectoryHelp,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  FormFieldValidator<String> _required(AppLocalizations l10n) => (value) {
    if (value == null || value.trim().isEmpty) return l10n.errorRequired;
    return null;
  };
}

class _TestResult extends StatelessWidget {
  const _TestResult({required this.success, required this.text});

  final bool success;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: success
              ? theme.colorScheme.onSecondaryContainer
              : theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

/// Picks a stored credential, with a shortcut to add one if it is missing.
class _CredentialPicker extends ConsumerWidget {
  const _CredentialPicker({
    required this.credentials,
    required this.selectedId,
    required this.onChanged,
    this.allowNone = false,
  });

  final List<Credential> credentials;
  final String? selectedId;
  final bool allowNone;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (credentials.isEmpty && !allowNone) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.key_outlined),
          title: Text(l10n.authNoKeysYet),
          subtitle: Text(l10n.authAddKey),
          trailing: const Icon(Icons.add),
          onTap: () => importOrGenerateKey(context, ref),
        ),
      );
    }

    final selected = credentials.any((item) => item.id == selectedId)
        ? selectedId
        : null;
    return DropdownButtonFormField<String?>(
      initialValue: selected,
      decoration: InputDecoration(labelText: l10n.authSelectCredential),
      items: [
        if (allowNone)
          DropdownMenuItem<String?>(child: Text(l10n.computerNoCredential)),
        for (final credential in credentials)
          DropdownMenuItem<String?>(
            value: credential.id,
            child: Text(credential.name),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
