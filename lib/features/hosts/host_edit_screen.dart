import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../core/platform/wake_on_lan.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import '../keys/key_actions.dart';

/// Create or edit a computer (SPEC 8.3).
///
/// Testing the connection is offered but never required: a user adding a
/// machine that is currently asleep should still be able to save it.
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
  final _port = TextEditingController(text: '${Host.defaultPort}');
  final _username = TextEditingController();
  final _startupDirectory = TextEditingController();
  final _notes = TextEditingController();

  final _wolMac = TextEditingController();
  final _wolBroadcast = TextEditingController(text: '255.255.255.255');
  final _wolPort = TextEditingController(text: '9');

  AuthMethod _authMethod = AuthMethod.privateKey;
  RemotePlatform _platform = RemotePlatform.posix;
  String? _credentialId;
  bool _favorite = false;
  bool _wolEnabled = false;

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
    final wol = await ref.read(wolRepositoryProvider).forHost(widget.hostId!);
    if (!mounted || host == null) {
      setState(() => _loaded = true);
      return;
    }

    setState(() {
      _existing = host;
      _name.text = host.name;
      _hostname.text = host.hostname;
      _port.text = '${host.port}';
      _username.text = host.username;
      _startupDirectory.text = host.startupDirectory ?? '';
      _notes.text = host.environmentNotes ?? '';
      _authMethod = host.authMethod;
      _platform = host.platform;
      _credentialId = host.credentialId;
      _favorite = host.favorite;
      if (wol != null) {
        _wolEnabled = true;
        _wolMac.text = wol.macAddress;
        _wolBroadcast.text = wol.broadcastAddress;
        _wolPort.text = '${wol.port}';
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _hostname,
      _port,
      _username,
      _startupDirectory,
      _notes,
      _wolMac,
      _wolBroadcast,
      _wolPort,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Host _buildHost() {
    final now = DateTime.now();
    final existing = _existing;

    if (existing != null) {
      return existing.copyWith(
        name: _name.text.trim(),
        hostname: _hostname.text.trim(),
        port: int.parse(_port.text.trim()),
        username: _username.text.trim(),
        authMethod: _authMethod,
        credentialId: _credentialId,
        startupDirectory: _emptyToNull(_startupDirectory.text),
        environmentNotes: _emptyToNull(_notes.text),
        platform: _platform,
        favorite: _favorite,
        updatedAt: now,
      );
    }

    return Host(
      id: const Uuid().v4(),
      name: _name.text.trim(),
      hostname: _hostname.text.trim(),
      port: int.parse(_port.text.trim()),
      username: _username.text.trim(),
      authMethod: _authMethod,
      credentialId: _credentialId,
      startupDirectory: _emptyToNull(_startupDirectory.text),
      environmentNotes: _emptyToNull(_notes.text),
      platform: _platform,
      favorite: _favorite,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Connects once to prove the settings work, then disconnects.
  ///
  /// This is a real connection, so it also walks the user through fingerprint
  /// verification here rather than in the middle of their first terminal.
  Future<void> _test() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final host = _buildHost();
    final l10n = AppLocalizations.of(context);

    try {
      final connection =
          await ref.read(connectionManagerProvider).connect(host);
      await ref.read(connectionManagerProvider).disconnect(host.id);
      if (!mounted) return;
      setState(() {
        _testSucceeded = connection.host.id == host.id;
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
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final host = _buildHost();

    // Changing the endpoint must not inherit the old machine's trust decision
    // (SPEC 8.4), so the trusted key for the previous address is dropped.
    final previous = _existing;
    if (previous != null &&
        (previous.hostname != host.hostname || previous.port != host.port)) {
      await ref.read(trustedKeysRepositoryProvider).revokeEndpoint(
            hostname: previous.hostname,
            port: previous.port,
          );
      await ref.read(connectionManagerProvider).disconnect(host.id);
    }

    await ref.read(hostsRepositoryProvider).upsert(host);

    if (_wolEnabled && WakeOnLan.isValidMac(_wolMac.text)) {
      await ref.read(wolRepositoryProvider).upsert(
            WolProfile(
              hostId: host.id,
              macAddress: _wolMac.text.trim(),
              broadcastAddress: _wolBroadcast.text.trim().isEmpty
                  ? '255.255.255.255'
                  : _wolBroadcast.text.trim(),
              port: int.tryParse(_wolPort.text.trim()) ?? 9,
            ),
          );
    } else if (!_wolEnabled) {
      await ref.read(wolRepositoryProvider).delete(host.id);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    context.go(Routes.hostDetail(host.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final credentials = ref.watch(credentialsProvider).valueOrNull ?? const [];

    if (!_loaded) {
      return const Scaffold(body: LoadingView());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.computerNew : l10n.computerEdit),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.actionSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            _SectionLabel(text: l10n.computerSectionConnection),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.computerFieldName,
                hintText: l10n.computerFieldNameHint,
              ),
              validator: _required(l10n),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hostname,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.computerFieldHostname,
                hintText: l10n.computerFieldHostnameHint,
              ),
              validator: _required(l10n),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
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
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _username,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.computerFieldUsername,
                    ),
                    validator: _required(l10n),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionLabel(text: l10n.computerSectionAuthentication),
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
              const SizedBox(height: 4),
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
            if (_authMethod == AuthMethod.keyboardInteractive) ...[
              const SizedBox(height: 8),
              Text(
                l10n.authMethodKeyboardInteractive,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering, size: 18),
              label: Text(
                _testing ? l10n.testConnectionRunning : l10n.actionTest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.testConnectionOptional,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSucceeded
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _testSucceeded
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            _SectionLabel(text: l10n.computerSectionOptions),
            DropdownButtonFormField<RemotePlatform>(
              initialValue: _platform,
              decoration: InputDecoration(
                labelText: l10n.computerFieldPlatform,
                helperText: l10n.computerFieldPlatformHelp,
                helperMaxLines: 3,
              ),
              items: [
                for (final platform in RemotePlatform.values)
                  DropdownMenuItem(
                    value: platform,
                    child: Text(platform.label),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _platform = value ?? RemotePlatform.posix),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _startupDirectory,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.computerFieldStartupDirectory,
                helperText: l10n.computerFieldStartupDirectoryHelp,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.computerFieldNotes,
                helperText: l10n.computerFieldNotesHelp,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _favorite,
              title: Text(l10n.computerFavorite),
              onChanged: (value) => setState(() => _favorite = value),
            ),

            const SizedBox(height: 12),
            _SectionLabel(text: l10n.computerSectionWol),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _wolEnabled,
              title: Text(l10n.wolEnable),
              subtitle: Text(l10n.wolBestEffort),
              onChanged: (value) => setState(() => _wolEnabled = value),
            ),
            if (_wolEnabled) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _wolMac,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.wolFieldMac,
                  hintText: l10n.wolFieldMacHint,
                ),
                validator: (value) {
                  if (!_wolEnabled) return null;
                  if (!WakeOnLan.isValidMac(value ?? '')) {
                    return l10n.wolInvalidMac;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _wolBroadcast,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.wolFieldBroadcast,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _wolPort,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.wolFieldPort,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? Function(String?) _required(AppLocalizations l10n) =>
      (value) => (value?.trim().isEmpty ?? true) ? l10n.errorRequired : null;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Picks a stored credential, with a shortcut to create one when none exist.
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

    final validSelection =
        credentials.any((credential) => credential.id == selectedId)
            ? selectedId
            : null;

    return DropdownButtonFormField<String?>(
      initialValue: validSelection,
      decoration: InputDecoration(labelText: l10n.authSelectCredential),
      items: [
        if (allowNone)
          DropdownMenuItem<String?>(
            child: Text(l10n.computerNoCredential),
          ),
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
