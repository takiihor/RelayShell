import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'terminal_input_modifiers.dart';

/// One key on the accessory row (SPEC 10.3).
class AccessoryKey {
  const AccessoryKey({
    required this.id,
    required this.label,
    this.sequence,
    this.isModifier = false,
    this.icon,
    this.width = 1,
  });

  final String id;
  final String label;

  /// Bytes sent when tapped. Null for modifiers, which alter the next key.
  final String? sequence;

  final bool isModifier;
  final IconData? icon;

  /// Relative width, so arrows stay compact and CTRL stays tappable.
  final double width;
}

/// The catalogue of keys a user can put on their rows.
///
/// Sequences are the real terminal escape codes rather than approximations,
/// because vim, tmux and interactive CLIs all distinguish them precisely.
class AccessoryKeys {
  const AccessoryKeys._();

  static const Map<String, AccessoryKey> all = {
    'esc': AccessoryKey(id: 'esc', label: 'ESC', sequence: '\x1b'),
    'ctrl': AccessoryKey(
      id: 'ctrl',
      label: 'CTRL',
      isModifier: true,
      width: 1.3,
    ),
    'alt': AccessoryKey(id: 'alt', label: 'ALT', isModifier: true),
    'tab': AccessoryKey(id: 'tab', label: 'TAB', sequence: '\t'),
    'up': AccessoryKey(
      id: 'up',
      label: '↑',
      sequence: '\x1b[A',
      icon: Icons.keyboard_arrow_up,
    ),
    'down': AccessoryKey(
      id: 'down',
      label: '↓',
      sequence: '\x1b[B',
      icon: Icons.keyboard_arrow_down,
    ),
    'left': AccessoryKey(
      id: 'left',
      label: '←',
      sequence: '\x1b[D',
      icon: Icons.keyboard_arrow_left,
    ),
    'right': AccessoryKey(
      id: 'right',
      label: '→',
      sequence: '\x1b[C',
      icon: Icons.keyboard_arrow_right,
    ),
    'home': AccessoryKey(id: 'home', label: 'HOME', sequence: '\x1b[H'),
    'end': AccessoryKey(id: 'end', label: 'END', sequence: '\x1b[F'),
    'pgup': AccessoryKey(id: 'pgup', label: 'PGUP', sequence: '\x1b[5~'),
    'pgdn': AccessoryKey(id: 'pgdn', label: 'PGDN', sequence: '\x1b[6~'),
    'pipe': AccessoryKey(id: 'pipe', label: '|', sequence: '|'),
    'tilde': AccessoryKey(id: 'tilde', label: '~', sequence: '~'),
    'slash': AccessoryKey(id: 'slash', label: '/', sequence: '/'),
    'backslash': AccessoryKey(id: 'backslash', label: r'\', sequence: r'\'),
    'dash': AccessoryKey(id: 'dash', label: '-', sequence: '-'),
    'underscore': AccessoryKey(id: 'underscore', label: '_', sequence: '_'),
    'colon': AccessoryKey(id: 'colon', label: ':', sequence: ':'),
    'semicolon': AccessoryKey(id: 'semicolon', label: ';', sequence: ';'),
    'star': AccessoryKey(id: 'star', label: '*', sequence: '*'),
    'ampersand': AccessoryKey(id: 'ampersand', label: '&', sequence: '&'),
    'dollar': AccessoryKey(id: 'dollar', label: r'$', sequence: r'$'),
    'quote': AccessoryKey(id: 'quote', label: "'", sequence: "'"),
    'dquote': AccessoryKey(id: 'dquote', label: '"', sequence: '"'),
    'ctrl_c': AccessoryKey(
      id: 'ctrl_c',
      label: '^C',
      sequence: '\x03',
      width: 1.2,
    ),
    'ctrl_d': AccessoryKey(
      id: 'ctrl_d',
      label: '^D',
      sequence: '\x04',
      width: 1.2,
    ),
    'ctrl_l': AccessoryKey(
      id: 'ctrl_l',
      label: '^L',
      sequence: '\x0c',
      width: 1.2,
    ),
    'ctrl_r': AccessoryKey(
      id: 'ctrl_r',
      label: '^R',
      sequence: '\x12',
      width: 1.2,
    ),
    'ctrl_z': AccessoryKey(
      id: 'ctrl_z',
      label: '^Z',
      sequence: '\x1a',
      width: 1.2,
    ),
    'ctrl_a': AccessoryKey(
      id: 'ctrl_a',
      label: '^A',
      sequence: '\x01',
      width: 1.2,
    ),
    'ctrl_e': AccessoryKey(
      id: 'ctrl_e',
      label: '^E',
      sequence: '\x05',
      width: 1.2,
    ),
  };

  /// Keys the settings screen offers, in a stable, groupable order.
  static List<AccessoryKey> get catalogue => all.values.toList();

  static AccessoryKey? byId(String id) => all[id];
}

/// The accessory key row above the keyboard (SPEC 10.3, 10.4).
///
/// Modifiers arm on tap and lock on long-press, with a visible difference
/// between the two — a locked CTRL that looks the same as an armed one is how
/// users end up sending `^X` to a shell they meant to type in.
class AccessoryKeyboard extends StatefulWidget {
  const AccessoryKeyboard({
    required this.rows,
    required this.onSequence,
    required this.modifiers,
    super.key,
    this.haptics = true,
  });

  final List<List<String>> rows;

  /// Called with the bytes to send.
  final void Function(String sequence) onSequence;

  final TerminalInputModifiers modifiers;

  final bool haptics;

  @override
  State<AccessoryKeyboard> createState() => _AccessoryKeyboardState();
}

class _AccessoryKeyboardState extends State<AccessoryKeyboard> {
  @override
  void initState() {
    super.initState();
    widget.modifiers.addListener(_modifiersChanged);
  }

  @override
  void didUpdateWidget(AccessoryKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modifiers == widget.modifiers) return;
    oldWidget.modifiers.removeListener(_modifiersChanged);
    widget.modifiers.addListener(_modifiersChanged);
  }

  @override
  void dispose() {
    widget.modifiers.removeListener(_modifiersChanged);
    super.dispose();
  }

  void _modifiersChanged() {
    if (mounted) setState(() {});
  }

  void _tapModifier(String id) {
    _feedback();
    if (id == 'ctrl') {
      widget.modifiers.tapControl();
    } else {
      widget.modifiers.tapAlt();
    }
  }

  void _lockModifier(String id) {
    _feedback(heavy: true);
    if (id == 'ctrl') {
      widget.modifiers.lockControl();
    } else {
      widget.modifiers.lockAlt();
    }
  }

  /// Applies armed modifiers to [sequence] and releases the armed ones.
  void _send(String sequence) {
    _feedback();
    widget.onSequence(widget.modifiers.applyAccessorySequence(sequence));
  }

  void _feedback({bool heavy = false}) {
    if (!widget.haptics) return;
    if (heavy) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in widget.rows)
              if (row.isNotEmpty)
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    children: [
                      for (final id in row)
                        if (AccessoryKeys.byId(id) case final key?)
                          _KeyButton(
                            accessoryKey: key,
                            state: key.id == 'ctrl'
                                ? widget.modifiers.control
                                : key.id == 'alt'
                                ? widget.modifiers.alt
                                : ModifierState.off,
                            onTap: () => key.isModifier
                                ? _tapModifier(key.id)
                                : _send(key.sequence ?? ''),
                            onLongPress: key.isModifier
                                ? () => _lockModifier(key.id)
                                : null,
                          ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.accessoryKey,
    required this.state,
    required this.onTap,
    this.onLongPress,
  });

  final AccessoryKey accessoryKey;
  final ModifierState state;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = state != ModifierState.off;
    final locked = state == ModifierState.locked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        label: accessoryKey.label,
        selected: active,
        child: Material(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(
                minWidth: 48 * accessoryKey.width,
                minHeight: 48,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (accessoryKey.icon != null)
                    Icon(
                      accessoryKey.icon,
                      size: 20,
                      color: active
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    )
                  else
                    Text(
                      accessoryKey.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontFamily: 'monospace',
                        color: active
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  // A locked modifier is marked, not just coloured, so the
                  // state is readable at a glance and without colour vision.
                  if (locked) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock,
                      size: 12,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
