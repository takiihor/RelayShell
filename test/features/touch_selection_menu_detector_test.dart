import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/features/terminal/touch_selection_menu_detector.dart';

void main() {
  Future<void> pumpDetector(WidgetTester tester, VoidCallback onLongPressEnd) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouchSelectionMenuDetector(
              onLongPressEnd: onLongPressEnd,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

  testWidgets('reports a touch long press after the pointer is released', (
    tester,
  ) async {
    var calls = 0;
    await pumpDetector(tester, () => calls++);

    final pointer = TestPointer(1, PointerDeviceKind.touch);
    await tester.sendEventToBinding(
      pointer.down(const Offset(100, 100), timeStamp: Duration.zero),
    );
    await tester.pump(kLongPressTimeout);
    expect(calls, 0);

    await tester.sendEventToBinding(
      pointer.up(
        timeStamp: kLongPressTimeout + const Duration(milliseconds: 1),
      ),
    );
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('ignores a drag that begins before the long press timeout', (
    tester,
  ) async {
    var calls = 0;
    await pumpDetector(tester, () => calls++);

    final pointer = TestPointer(1, PointerDeviceKind.touch);
    await tester.sendEventToBinding(
      pointer.down(const Offset(100, 100), timeStamp: Duration.zero),
    );
    await tester.sendEventToBinding(
      pointer.move(
        const Offset(100, 140),
        timeStamp: const Duration(milliseconds: 100),
      ),
    );
    await tester.pump(kLongPressTimeout);
    await tester.sendEventToBinding(
      pointer.up(timeStamp: const Duration(milliseconds: 600)),
    );
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('ignores a multi-touch hold', (tester) async {
    var calls = 0;
    await pumpDetector(tester, () => calls++);

    final first = TestPointer(1, PointerDeviceKind.touch);
    final second = TestPointer(2, PointerDeviceKind.touch);
    await tester.sendEventToBinding(
      first.down(const Offset(100, 100), timeStamp: Duration.zero),
    );
    await tester.sendEventToBinding(
      second.down(
        const Offset(150, 100),
        timeStamp: const Duration(milliseconds: 100),
      ),
    );
    await tester.pump(kLongPressTimeout);
    await tester.sendEventToBinding(
      first.up(timeStamp: const Duration(milliseconds: 600)),
    );
    await tester.sendEventToBinding(
      second.up(timeStamp: const Duration(milliseconds: 600)),
    );
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('allows selection dragging after the long press begins', (
    tester,
  ) async {
    var calls = 0;
    await pumpDetector(tester, () => calls++);

    final pointer = TestPointer(1, PointerDeviceKind.touch);
    await tester.sendEventToBinding(
      pointer.down(const Offset(100, 100), timeStamp: Duration.zero),
    );
    await tester.sendEventToBinding(
      pointer.move(
        const Offset(100, 160),
        timeStamp: kLongPressTimeout + const Duration(milliseconds: 10),
      ),
    );
    await tester.sendEventToBinding(
      pointer.up(
        timeStamp: kLongPressTimeout + const Duration(milliseconds: 20),
      ),
    );
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('ignores a cancelled long press', (tester) async {
    var calls = 0;
    await pumpDetector(tester, () => calls++);

    final pointer = TestPointer(1, PointerDeviceKind.touch);
    await tester.sendEventToBinding(
      pointer.down(const Offset(100, 100), timeStamp: Duration.zero),
    );
    await tester.sendEventToBinding(
      pointer.cancel(
        timeStamp: kLongPressTimeout + const Duration(milliseconds: 1),
      ),
    );
    await tester.pump();

    expect(calls, 0);
  });
}
