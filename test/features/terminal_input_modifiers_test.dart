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
}
