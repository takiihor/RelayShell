import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/features/terminal/accessory_keyboard.dart';
import 'package:relayshell/features/terminal/terminal_input_modifiers.dart';
import 'package:relayshell/shared/models/app_preferences.dart';

void main() {
  test('default mobile rows expose coding-agent essentials', () {
    final keys = AppPreferences.defaultAccessoryRows.expand((row) => row).toSet();

    expect(keys, containsAll(<String>['ctrl', 'shift', 'tab', 'slash', 'ctrl_c']));
  });

  testWidgets('accessory keys provide a 48dp touch target', (tester) async {
    final modifiers = TerminalInputModifiers();
    addTearDown(modifiers.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in const [Size(375, 812), Size(812, 375)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessoryKeyboard(
              rows: const [
                ['ctrl'],
              ],
              haptics: false,
              modifiers: modifiers,
              onSequence: (_) {},
            ),
          ),
        ),
      );

      final target = tester.getSize(find.byType(InkWell));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('safe-area bottom can be delegated to a following composer', (
    tester,
  ) async {
    final modifiers = TerminalInputModifiers();
    addTearDown(modifiers.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessoryKeyboard(
            rows: const [
              ['ctrl'],
            ],
            haptics: false,
            safeAreaBottom: false,
            modifiers: modifiers,
            onSequence: (_) {},
          ),
        ),
      ),
    );

    final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
    expect(safeArea.bottom, isFalse);
  });

  testWidgets('long pressing CTRL locks it', (tester) async {
    final modifiers = TerminalInputModifiers();
    addTearDown(modifiers.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessoryKeyboard(
            rows: const [
              ['ctrl'],
            ],
            haptics: false,
            modifiers: modifiers,
            onSequence: (_) {},
          ),
        ),
      ),
    );

    await tester.longPress(find.text('CTRL'));
    await tester.pump();

    expect(modifiers.control, ModifierState.locked);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('SHIFT arms visibly and modifies the next accessory key', (
    tester,
  ) async {
    final modifiers = TerminalInputModifiers();
    addTearDown(modifiers.dispose);
    final output = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessoryKeyboard(
            rows: const [
              ['shift', 'slash'],
            ],
            haptics: false,
            modifiers: modifiers,
            onSequence: output.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('SHIFT'));
    await tester.pump();
    expect(modifiers.shift, ModifierState.armed);

    await tester.tap(find.text('/'));
    await tester.pump();

    expect(output, ['?']);
    expect(modifiers.shift, ModifierState.off);
  });
}
