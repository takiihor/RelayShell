import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/features/terminal/terminal_input_modifiers.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('armed CTRL transforms soft-keyboard terminal input', () {
    final modifiers = TerminalInputModifiers()..tapControl();
    final output = <String>[];
    final terminal = Terminal(
      onOutput: (data) => output.add(modifiers.applyTerminalInput(data)),
    );

    terminal.textInput('c');

    expect(output, ['\x03']);
    expect(modifiers.control, ModifierState.off);
  });

  test('armed CTRL does not consume a multi-character paste', () {
    final modifiers = TerminalInputModifiers()..tapControl();

    expect(modifiers.applyTerminalInput('pasted text'), 'pasted text');
    expect(modifiers.control, ModifierState.armed);
  });

  test('active modifier state covers CTRL, ALT and SHIFT', () {
    final modifiers = TerminalInputModifiers();
    expect(modifiers.hasActiveModifier, isFalse);

    modifiers.tapControl();
    expect(modifiers.hasActiveModifier, isTrue);
    modifiers.tapControl();
    expect(modifiers.hasActiveModifier, isFalse);

    modifiers.tapAlt();
    expect(modifiers.hasActiveModifier, isTrue);
    modifiers.tapAlt();

    modifiers.tapShift();
    expect(modifiers.hasActiveModifier, isTrue);
  });

  test('modifier listeners observe the newly armed state', () {
    final modifiers = TerminalInputModifiers();
    ModifierState? observed;
    modifiers.addListener(() => observed = modifiers.control);

    modifiers.tapControl();

    expect(observed, ModifierState.armed);
  });

  test('SHIFT+TAB emits xterm back-tab and releases armed shift', () {
    final modifiers = TerminalInputModifiers()..tapShift();

    expect(modifiers.applyAccessorySequence('\t'), '\x1b[Z');
    expect(modifiers.shift, ModifierState.off);
  });

  test('SHIFT modifies arrows using xterm modifier parameter 2', () {
    final modifiers = TerminalInputModifiers()..tapShift();

    expect(modifiers.applyAccessorySequence('\x1b[A'), '\x1b[1;2A');
  });

  test('SHIFT+/ produces question mark for mobile shell input', () {
    final modifiers = TerminalInputModifiers()..tapShift();

    expect(modifiers.applyAccessorySequence('/'), '?');
  });

  test('locked SHIFT remains active across accessory keys', () {
    final modifiers = TerminalInputModifiers()..lockShift();

    expect(modifiers.applyAccessorySequence('/'), '?');
    expect(modifiers.applyAccessorySequence('a'), 'A');
    expect(modifiers.shift, ModifierState.locked);
  });
}
