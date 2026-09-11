import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/shell/tmux.dart';
import 'package:xterm/xterm.dart';

/// Pins the behaviour behind "I cannot scroll up when a full-screen program is
/// running" (tmux, Herdr, or anything else that uses the alternate screen).
///
/// The alternate screen buffer has no scrollback of its own, so xterm.dart
/// stops scrolling the view and forwards the gesture to the remote program as
/// mouse-wheel events instead — but only when that program has asked for mouse
/// reporting. With no mouse reporting the drag produces nothing at all, which
/// is exactly what a default tmux felt like.
void main() {
  /// Drags a finger down the terminal and returns everything it sent upstream.
  Future<List<String>> dragUp(
    WidgetTester tester, {
    required bool mouseReporting,
  }) async {
    final terminal = Terminal(maxLines: 2000);
    final sent = <String>[];
    terminal.onOutput = sent.add;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TerminalView(terminal, autofocus: true))),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 200; i++) {
      terminal.write('line $i\r\n');
    }
    await tester.pumpAndSettle();

    // Enter the alternate screen, as a multiplexer does on attach.
    terminal.write('\x1b[?1049h');
    await tester.pumpAndSettle();
    if (mouseReporting) {
      // SGR mouse reporting, as tmux with `mouse on` and Herdr both enable.
      terminal.write('\x1b[?1000h\x1b[?1006h');
      await tester.pumpAndSettle();
    }
    expect(terminal.isUsingAltBuffer, isTrue);

    sent.clear();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TerminalView)),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    return sent;
  }

  testWidgets('a drag scrolls when the remote program reports mouse', (
    tester,
  ) async {
    final sent = await dragUp(tester, mouseReporting: true);

    expect(sent, isNotEmpty, reason: 'the drag must reach the remote program');
    // SGR wheel-up is button 64 (+4 when a modifier is set), encoded `<6…M`.
    expect(sent.every((event) => event.startsWith('\x1b[<6')), isTrue);
  });

  testWidgets('a drag is silently dead without mouse reporting', (
    tester,
  ) async {
    // This is the bug, pinned rather than fixed in the app: the alternate
    // buffer cannot scroll and xterm.dart's arrow-key fallback never fires, so
    // the fix has to be at the other end — make the multiplexer ask for mouse
    // reporting. See [TmuxCommandBuilder.sessionSetup].
    expect(await dragUp(tester, mouseReporting: false), isEmpty);
  });

  test('the tmux prelude is what turns mouse reporting on', () {
    expect(TmuxCommandBuilder.sessionSetup, contains('set -g mouse on'));
  });
}
