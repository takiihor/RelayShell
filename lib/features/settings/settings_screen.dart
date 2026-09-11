import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../shared/navigation/routes.dart';
import '../../shared/theme/terminal_themes.dart';
import '../../core/storage/config_transfer.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import 'accessory_keys_screen.dart';

/// All user-configurable settings (SPEC 21).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preferences = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);
    final trustedKeys = ref.watch(trustedKeysProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(title: l10n.settingsAppearance),
          ListTile(
            title: Text(l10n.settingsThemeMode),
            trailing: DropdownButton<AppThemeMode>(
              value: preferences.themeMode,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text(l10n.settingsThemeSystem),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text(l10n.settingsThemeLight),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text(l10n.settingsThemeDark),
                ),
              ],
              onChanged: (value) => value == null
                  ? null
                  : controller.edit((c) => c.copyWith(themeMode: value)),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsTerminalTheme),
            trailing: DropdownButton<String>(
              value: preferences.terminalThemeId,
              underline: const SizedBox.shrink(),
              items: [
                for (final theme in TerminalThemeCatalog.all)
                  DropdownMenuItem(value: theme.id, child: Text(theme.name)),
              ],
              onChanged: (value) => value == null
                  ? null
                  : controller.edit((c) => c.copyWith(terminalThemeId: value)),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsTerminalFont),
            trailing: DropdownButton<String>(
              value: preferences.terminalFontFamily,
              underline: const SizedBox.shrink(),
              items: [
                for (final font in TerminalFonts.available)
                  DropdownMenuItem(value: font, child: Text(font)),
              ],
              onChanged: (value) => value == null
                  ? null
                  : controller.edit(
                      (c) => c.copyWith(terminalFontFamily: value),
                    ),
            ),
          ),
          _SliderTile(
            title: l10n.settingsFontSize,
            value: preferences.terminalFontSize,
            min: TerminalFonts.minSize,
            max: TerminalFonts.maxSize,
            label: preferences.terminalFontSize.toStringAsFixed(0),
            onChanged: (value) =>
                controller.edit((c) => c.copyWith(terminalFontSize: value)),
          ),
          ListTile(
            title: Text(l10n.settingsCursorStyle),
            trailing: DropdownButton<TerminalCursorStyle>(
              value: preferences.cursorStyle,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: TerminalCursorStyle.block,
                  child: Text(l10n.settingsCursorBlock),
                ),
                DropdownMenuItem(
                  value: TerminalCursorStyle.underline,
                  child: Text(l10n.settingsCursorUnderline),
                ),
                DropdownMenuItem(
                  value: TerminalCursorStyle.bar,
                  child: Text(l10n.settingsCursorBar),
                ),
              ],
              onChanged: (value) => value == null
                  ? null
                  : controller.edit((c) => c.copyWith(cursorStyle: value)),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsHaptics),
            value: preferences.hapticFeedback,
            onChanged: (value) =>
                controller.edit((c) => c.copyWith(hapticFeedback: value)),
          ),
          SwitchListTile(
            title: Text(l10n.settingsKeepAwake),
            value: preferences.keepScreenAwake,
            onChanged: (value) =>
                controller.edit((c) => c.copyWith(keepScreenAwake: value)),
          ),

          SectionHeader(title: l10n.settingsTerminal),
          _SliderTile(
            title: l10n.settingsScrollback,
            value: preferences.scrollbackLines.toDouble(),
            min: 200,
            max: 20000,
            divisions: 99,
            label: l10n.settingsLines(preferences.scrollbackLines),
            onChanged: (value) => controller.edit(
              (c) => c.copyWith(scrollbackLines: value.round()),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsAccessoryKeys),
            subtitle: Text(l10n.settingsAccessoryKeysHelp),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const AccessoryKeysScreen(),
              ),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsCopyOnSelect),
            value: preferences.copyOnSelect,
            onChanged: (value) =>
                controller.edit((c) => c.copyWith(copyOnSelect: value)),
          ),
          SwitchListTile(
            title: Text(l10n.settingsPasteConfirm),
            value: preferences.confirmMultilinePaste,
            onChanged: (value) => controller.edit(
              (c) => c.copyWith(confirmMultilinePaste: value),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsDefaultSession),
            trailing: DropdownButton<SessionMode>(
              value: preferences.defaultSessionMode,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: SessionMode.direct,
                  child: Text(l10n.sessionModeDirect),
                ),
                DropdownMenuItem(
                  value: SessionMode.persistent,
                  child: Text(
                    l10n.sessionModePersistentNamed(
                      preferences.defaultMultiplexer.label,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => value == null
                  ? null
                  : controller.edit(
                      (c) => c.copyWith(defaultSessionMode: value),
                    ),
            ),
          ),

          SectionHeader(title: l10n.settingsSsh),
          _SliderTile(
            title: l10n.settingsKeepalive,
            value: preferences.keepaliveSeconds.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            label: l10n.settingsSeconds(preferences.keepaliveSeconds),
            onChanged: (value) => controller.edit(
              (c) => c.copyWith(keepaliveSeconds: value.round()),
            ),
          ),
          _SliderTile(
            title: l10n.settingsConnectTimeout,
            value: preferences.connectTimeoutSeconds.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: l10n.settingsSeconds(preferences.connectTimeoutSeconds),
            onChanged: (value) => controller.edit(
              (c) => c.copyWith(connectTimeoutSeconds: value.round()),
            ),
          ),
          _SliderTile(
            title: l10n.settingsAuthTimeout,
            value: preferences.authTimeoutSeconds.toDouble(),
            min: 10,
            max: 120,
            divisions: 11,
            label: l10n.settingsSeconds(preferences.authTimeoutSeconds),
            onChanged: (value) => controller.edit(
              (c) => c.copyWith(authTimeoutSeconds: value.round()),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsTerminalType),
            trailing: DropdownButton<String>(
              value: preferences.terminalType,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: 'xterm-256color',
                  child: Text('xterm-256color'),
                ),
                DropdownMenuItem(value: 'xterm', child: Text('xterm')),
                DropdownMenuItem(value: 'vt100', child: Text('vt100')),
              ],
              onChanged: (value) => value == null
                  ? null
                  : controller.edit((c) => c.copyWith(terminalType: value)),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsReconnect),
            trailing: DropdownButton<ReconnectBehavior>(
              value: preferences.reconnectBehavior,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: ReconnectBehavior.ask,
                  child: Text(l10n.settingsReconnectAsk),
                ),
                DropdownMenuItem(
                  value: ReconnectBehavior.autoOnce,
                  child: Text(l10n.settingsReconnectOnce),
                ),
                DropdownMenuItem(
                  value: ReconnectBehavior.autoBounded,
                  child: Text(l10n.settingsReconnectBounded),
                ),
              ],
              onChanged: (value) => value == null
                  ? null
                  : controller.edit(
                      (c) => c.copyWith(reconnectBehavior: value),
                    ),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsDefaultMultiplexer),
            subtitle: Text(
              preferences.defaultMultiplexer == MultiplexerKind.herdr
                  ? l10n.multiplexerHerdrHelp
                  : l10n.multiplexerTmuxHelp,
            ),
            isThreeLine: true,
            trailing: DropdownButton<MultiplexerKind>(
              value: preferences.defaultMultiplexer,
              items: [
                for (final kind in MultiplexerKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(preferencesProvider.notifier)
                    .edit((c) => c.copyWith(defaultMultiplexer: value));
              },
            ),
          ),
          ListTile(
            title: Text(l10n.settingsTmuxPrefix),
            subtitle: Text(
              preferences.tmuxSessionPrefix,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTmuxPrefix(context, ref, preferences),
          ),

          SectionHeader(title: l10n.settingsSecurity),
          SwitchListTile(
            title: Text(l10n.settingsAppLock),
            subtitle: Text(l10n.settingsAppLockHelp),
            value: preferences.appLockEnabled,
            onChanged: (value) => _toggleAppLock(context, ref, value),
          ),
          if (preferences.appLockEnabled)
            ListTile(
              title: Text(l10n.settingsAppLockTimeout),
              trailing: DropdownButton<AppLockTimeout>(
                value: preferences.appLockTimeout,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: AppLockTimeout.immediately,
                    child: Text(l10n.settingsLockImmediately),
                  ),
                  DropdownMenuItem(
                    value: AppLockTimeout.oneMinute,
                    child: Text(l10n.settingsLockOneMinute),
                  ),
                  DropdownMenuItem(
                    value: AppLockTimeout.fiveMinutes,
                    child: Text(l10n.settingsLockFiveMinutes),
                  ),
                  DropdownMenuItem(
                    value: AppLockTimeout.fifteenMinutes,
                    child: Text(l10n.settingsLockFifteenMinutes),
                  ),
                ],
                onChanged: (value) => value == null
                    ? null
                    : controller.edit((c) => c.copyWith(appLockTimeout: value)),
              ),
            ),
          SwitchListTile(
            title: Text(l10n.settingsCredentialBiometric),
            value: preferences.credentialBiometricDefault,
            onChanged: (value) => controller.edit(
              (c) => c.copyWith(credentialBiometricDefault: value),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsTrustedKeys),
            subtitle: Text(l10n.settingsTrustedKeysCount(trustedKeys.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.trustedKeys),
          ),
          SwitchListTile(
            title: Text(l10n.settingsClearClipboard),
            value: preferences.clearClipboardAfterSecrets,
            onChanged: (value) => controller.edit(
              (c) => c.copyWith(clearClipboardAfterSecrets: value),
            ),
          ),

          SectionHeader(title: l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.settingsExport),
            subtitle: Text(l10n.settingsExportHelp),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.settingsImport),
            subtitle: Text(l10n.settingsImportHelp),
            onTap: () => _import(context, ref),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.settingsReset,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(l10n.settingsResetHelp),
            onTap: () => _reset(context, ref),
          ),
        ],
      ),
    );
  }

  /// Refuses to enable the lock when the device cannot satisfy it.
  ///
  /// Turning on a lock that can never be unlocked would strand the user's own
  /// hosts behind a prompt that always fails.
  Future<void> _toggleAppLock(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l10n = AppLocalizations.of(context);

    if (value) {
      final available = await ref
          .read(appServicesProvider)
          .biometrics
          .isAvailable;
      if (!context.mounted) return;
      if (!available) {
        showMessage(context, l10n.settingsAppLockHelp, isError: true);
        return;
      }
    }

    await ref
        .read(preferencesProvider.notifier)
        .edit((c) => c.copyWith(appLockEnabled: value));
  }

  Future<void> _editTmuxPrefix(
    BuildContext context,
    WidgetRef ref,
    AppPreferences preferences,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: preferences.tmuxSessionPrefix,
    );

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsTmuxPrefix),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);

    if (value == null || value.isEmpty) return;
    await ref
        .read(preferencesProvider.notifier)
        .edit((c) => c.copyWith(tmuxSessionPrefix: value));
  }

  /// Exports configuration to a shareable JSON file (SPEC 22).
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final json = await ref.read(configTransferProvider).exportToJson();
    final directory = await getTemporaryDirectory();
    final file = File(
      p.join(directory.path, ConfigTransfer.suggestedFileName()),
    );
    await file.writeAsString(json);

    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: l10n.settingsExport,
        // Stated on the share sheet so nobody assumes a backup carries keys.
        text: l10n.exportNoSecretsNotice,
      ),
    );

    if (context.mounted) showMessage(context, l10n.exportSuccess);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null || !context.mounted) return;

    try {
      final bytes = await picked.readAsBytes();
      final summary = await ref
          .read(configTransferProvider)
          .import(utf8.decode(bytes, allowMalformed: true));
      if (!context.mounted) return;

      if (summary.warnings.isEmpty) {
        showMessage(context, l10n.importSuccess(summary.total));
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.importWarnings),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.importSuccess(summary.total)),
                const SizedBox(height: 12),
                for (final warning in summary.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $warning'),
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
        ),
      );
    } on ConfigImportException catch (error) {
      if (context.mounted) showMessage(context, error.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, l10n.importFailed, isError: true);
      }
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await confirmDestructive(
      context,
      title: l10n.settingsResetTitle,
      body: l10n.settingsResetBody,
      confirmLabel: l10n.settingsResetConfirm,
    );
    if (!confirmed) return;

    await ref.read(appServicesProvider).resetEverything();
    if (context.mounted) {
      showMessage(context, l10n.settingsResetConfirm);
      context.go(Routes.home);
    }
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.divisions,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final String label;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
