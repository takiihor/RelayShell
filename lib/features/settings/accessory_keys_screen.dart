import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/common.dart';
import '../terminal/accessory_keyboard.dart';
import '../terminal/terminal_input_modifiers.dart';

/// Lets the user choose which keys appear above the keyboard (SPEC 10.3).
///
/// Two rows, edited independently, because the first row is muscle memory
/// (ESC, CTRL, arrows) while the second is personal (the symbols a given
/// person's shell habits need).
class AccessoryKeysScreen extends ConsumerStatefulWidget {
  const AccessoryKeysScreen({super.key});

  @override
  ConsumerState<AccessoryKeysScreen> createState() =>
      _AccessoryKeysScreenState();
}

class _AccessoryKeysScreenState extends ConsumerState<AccessoryKeysScreen> {
  final TerminalInputModifiers _modifiers = TerminalInputModifiers();

  @override
  void dispose() {
    _modifiers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);

    final rows = preferences.accessoryKeyRows;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsAccessoryKeys),
        actions: [
          TextButton(
            onPressed: () => controller.edit(
              (c) => c.copyWith(accessoryKeyRows: AppPreferencesDefaults.rows),
            ),
            child: Text(l10n.actionClear),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.settingsAccessoryKeysHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (var rowIndex = 0; rowIndex < 2; rowIndex++) ...[
            SectionHeader(
              title: '${l10n.settingsAccessoryKeys} ${rowIndex + 1}',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in AccessoryKeys.catalogue)
                    FilterChip(
                      label: Text(
                        key.label,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      selected:
                          rowIndex < rows.length &&
                          rows[rowIndex].contains(key.id),
                      onSelected: (selected) =>
                          _toggle(controller, rows, rowIndex, key.id, selected),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(title: l10n.terminalTitle),
          AccessoryKeyboard(
            rows: rows,
            haptics: false,
            modifiers: _modifiers,
            onSequence: (_) {},
          ),
        ],
      ),
    );
  }

  void _toggle(
    PreferencesController controller,
    List<List<String>> rows,
    int rowIndex,
    String keyId,
    bool selected,
  ) {
    final next = [
      for (var i = 0; i < 2; i++)
        [...(i < rows.length ? rows[i] : const <String>[])],
    ];

    // A key belongs to exactly one row, so selecting it elsewhere moves it
    // rather than duplicating it.
    for (final row in next) {
      row.remove(keyId);
    }
    if (selected) next[rowIndex].add(keyId);

    controller.edit((c) => c.copyWith(accessoryKeyRows: next));
  }
}

/// Exposes the shipped default rows for the reset action.
class AppPreferencesDefaults {
  const AppPreferencesDefaults._();

  static const List<List<String>> rows = [
    ['esc', 'ctrl', 'alt', 'tab', 'up', 'left', 'down', 'right'],
    ['pipe', 'tilde', 'slash', 'dash', 'underscore', 'colon', 'ctrl_c'],
  ];
}
