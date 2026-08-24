import 'package:flutter/foundation.dart';

/// Modifier latch state: off, armed for one key, or locked.
enum ModifierState { off, armed, locked }

/// Shared CTRL/ALT state for accessory keys and terminal keyboard input.
class TerminalInputModifiers extends ChangeNotifier {
  ModifierState _control = ModifierState.off;
  ModifierState _alt = ModifierState.off;

  ModifierState get control => _control;
  ModifierState get alt => _alt;

  void tapControl() => _control = _tap(_control);
  void tapAlt() => _alt = _tap(_alt);
  void lockControl() => _control = _lock(_control);
  void lockAlt() => _alt = _lock(_alt);

  ModifierState _tap(ModifierState current) {
    final next = switch (current) {
      ModifierState.off => ModifierState.armed,
      ModifierState.armed || ModifierState.locked => ModifierState.off,
    };
    notifyListeners();
    return next;
  }

  ModifierState _lock(ModifierState current) {
    final next = current == ModifierState.locked
        ? ModifierState.off
        : ModifierState.locked;
    notifyListeners();
    return next;
  }

  /// Applies modifiers to a key emitted by the accessory row.
  String applyAccessorySequence(String sequence) => _apply(sequence);

  /// Applies modifiers to one keyboard character emitted by TerminalView.
  ///
  /// Multi-character input is a paste or IME commit, not a single keypress, so
  /// it passes through and leaves an armed modifier waiting for the next key.
  String applyTerminalInput(String input) {
    if ((_control != ModifierState.off || _alt != ModifierState.off) &&
        input.runes.length != 1) {
      return input;
    }
    return _apply(input);
  }

  String _apply(String input) {
    var output = input;

    if (_control != ModifierState.off) {
      output = _applyControl(output);
    }
    if (_alt != ModifierState.off) {
      output = '\x1b$output';
    }

    var changed = false;
    if (_control == ModifierState.armed) {
      _control = ModifierState.off;
      changed = true;
    }
    if (_alt == ModifierState.armed) {
      _alt = ModifierState.off;
      changed = true;
    }
    if (changed) notifyListeners();

    return output;
  }

  static String _applyControl(String input) {
    if (input.isEmpty) return input;
    final code = input.codeUnitAt(0);

    if (code >= 0x61 && code <= 0x7a) {
      return String.fromCharCode(code - 0x60);
    }
    if (code >= 0x41 && code <= 0x5a) {
      return String.fromCharCode(code - 0x40);
    }
    return switch (input) {
      '[' => '\x1b',
      r'\' => '\x1c',
      ']' => '\x1d',
      '^' => '\x1e',
      '_' => '\x1f',
      ' ' => '\x00',
      _ => input,
    };
  }
}
