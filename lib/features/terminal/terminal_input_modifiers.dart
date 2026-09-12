import 'package:flutter/foundation.dart';

/// Modifier latch state: off, armed for one key, or locked.
enum ModifierState { off, armed, locked }

/// Shared CTRL/ALT/SHIFT state for accessory keys and terminal keyboard input.
class TerminalInputModifiers extends ChangeNotifier {
  ModifierState _control = ModifierState.off;
  ModifierState _alt = ModifierState.off;
  ModifierState _shift = ModifierState.off;

  ModifierState get control => _control;
  ModifierState get alt => _alt;
  ModifierState get shift => _shift;

  bool get hasActiveModifier =>
      _control != ModifierState.off ||
      _alt != ModifierState.off ||
      _shift != ModifierState.off;

  void tapControl() {
    _control = _tap(_control);
    notifyListeners();
  }

  void tapAlt() {
    _alt = _tap(_alt);
    notifyListeners();
  }

  void tapShift() {
    _shift = _tap(_shift);
    notifyListeners();
  }

  void lockControl() {
    _control = _lock(_control);
    notifyListeners();
  }

  void lockAlt() {
    _alt = _lock(_alt);
    notifyListeners();
  }

  void lockShift() {
    _shift = _lock(_shift);
    notifyListeners();
  }

  static ModifierState _tap(ModifierState current) => switch (current) {
    ModifierState.off => ModifierState.armed,
    ModifierState.armed || ModifierState.locked => ModifierState.off,
  };

  static ModifierState _lock(ModifierState current) =>
      current == ModifierState.locked ? ModifierState.off : ModifierState.locked;

  /// Applies modifiers to a key emitted by the accessory row.
  String applyAccessorySequence(String sequence) => _apply(sequence);

  /// Applies modifiers to one keyboard character emitted by TerminalView.
  ///
  /// Multi-character input is a paste or IME commit, not a single keypress, so
  /// it passes through and leaves armed modifiers waiting for the next key.
  String applyTerminalInput(String input) {
    if (hasActiveModifier && input.runes.length != 1) {
      return input;
    }
    return _apply(input);
  }

  String _apply(String input) {
    var output = input;

    // SHIFT must be applied before CTRL. For example Shift+C followed by CTRL
    // still produces ^C, while Shift+Tab becomes the terminal back-tab escape
    // sequence used by coding CLIs to cycle modes.
    if (_shift != ModifierState.off) {
      output = _applyShift(output);
    }
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
    if (_shift == ModifierState.armed) {
      _shift = ModifierState.off;
      changed = true;
    }
    if (changed) notifyListeners();

    return output;
  }

  static String _applyShift(String input) {
    if (input.isEmpty) return input;

    // xterm modifier parameter 2 is Shift. These are the sequences interactive
    // TUIs and coding agents expect rather than a textual approximation.
    return switch (input) {
      '\t' => '\x1b[Z',
      '\x1b[A' => '\x1b[1;2A',
      '\x1b[B' => '\x1b[1;2B',
      '\x1b[C' => '\x1b[1;2C',
      '\x1b[D' => '\x1b[1;2D',
      '\x1b[H' => '\x1b[1;2H',
      '\x1b[F' => '\x1b[1;2F',
      '\x1b[5~' => '\x1b[5;2~',
      '\x1b[6~' => '\x1b[6;2~',
      _ => _shiftPrintable(input),
    };
  }

  static String _shiftPrintable(String input) {
    if (input.runes.length != 1) return input;
    final code = input.codeUnitAt(0);
    if (code >= 0x61 && code <= 0x7a) {
      return String.fromCharCode(code - 0x20);
    }

    return switch (input) {
      '1' => '!',
      '2' => '@',
      '3' => '#',
      '4' => r'$',
      '5' => '%',
      '6' => '^',
      '7' => '&',
      '8' => '*',
      '9' => '(',
      '0' => ')',
      '-' => '_',
      '=' => '+',
      '[' => '{',
      ']' => '}',
      r'\' => '|',
      ';' => ':',
      "'" => '"',
      ',' => '<',
      '.' => '>',
      '/' => '?',
      '`' => '~',
      _ => input,
    };
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
