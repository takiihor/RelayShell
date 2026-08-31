import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/features/terminal/two_finger_swipe_detector.dart';

void main() {
  Future<void> pumpDetector(
    WidgetTester tester,
    List<TwoFingerSwipeDirection> swipes,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TwoFingerSwipeDetector(
          onSwipe: swipes.add,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );

  testWidgets('recognises a two-finger horizontal swipe', (tester) async {
    final swipes = <TwoFingerSwipeDirection>[];
    await pumpDetector(tester, swipes);

    final first = TestPointer(1, PointerDeviceKind.touch);
    final second = TestPointer(2, PointerDeviceKind.touch);
    await tester.sendEventToBinding(first.down(const Offset(240, 320)));
    await tester.sendEventToBinding(second.down(const Offset(320, 320)));
    await tester.sendEventToBinding(first.move(const Offset(150, 324)));
    await tester.sendEventToBinding(second.move(const Offset(230, 323)));
    await tester.pump();

    expect(swipes, [TwoFingerSwipeDirection.left]);
  });

  testWidgets('ignores a one-finger horizontal drag', (tester) async {
    final swipes = <TwoFingerSwipeDirection>[];
    await pumpDetector(tester, swipes);

    final pointer = TestPointer(1, PointerDeviceKind.touch);
    await tester.sendEventToBinding(pointer.down(const Offset(240, 320)));
    await tester.sendEventToBinding(pointer.move(const Offset(120, 320)));
    await tester.pump();

    expect(swipes, isEmpty);
  });

  testWidgets('recognises a right swipe', (tester) async {
    final swipes = <TwoFingerSwipeDirection>[];
    await pumpDetector(tester, swipes);

    final first = TestPointer(1, PointerDeviceKind.touch);
    final second = TestPointer(2, PointerDeviceKind.touch);
    await tester.sendEventToBinding(first.down(const Offset(100, 320)));
    await tester.sendEventToBinding(second.down(const Offset(180, 320)));
    await tester.sendEventToBinding(first.move(const Offset(190, 324)));
    await tester.sendEventToBinding(second.move(const Offset(270, 323)));
    await tester.pump();

    expect(swipes, [TwoFingerSwipeDirection.right]);
  });

  testWidgets('ignores a diagonal two-finger drag', (tester) async {
    final swipes = <TwoFingerSwipeDirection>[];
    await pumpDetector(tester, swipes);

    final first = TestPointer(1, PointerDeviceKind.touch);
    final second = TestPointer(2, PointerDeviceKind.touch);
    await tester.sendEventToBinding(first.down(const Offset(240, 240)));
    await tester.sendEventToBinding(second.down(const Offset(320, 240)));
    await tester.sendEventToBinding(first.move(const Offset(160, 300)));
    await tester.sendEventToBinding(second.move(const Offset(240, 300)));
    await tester.pump();

    expect(swipes, isEmpty);
  });

  testWidgets('ignores fingers moving in opposite directions', (tester) async {
    final swipes = <TwoFingerSwipeDirection>[];
    await pumpDetector(tester, swipes);

    final first = TestPointer(1, PointerDeviceKind.touch);
    final second = TestPointer(2, PointerDeviceKind.touch);
    await tester.sendEventToBinding(first.down(const Offset(200, 320)));
    await tester.sendEventToBinding(second.down(const Offset(280, 320)));
    await tester.sendEventToBinding(first.move(const Offset(110, 320)));
    await tester.sendEventToBinding(second.move(const Offset(370, 320)));
    await tester.pump();

    expect(swipes, isEmpty);
  });

  testWidgets('a third pointer cancels recognition', (tester) async {
    final swipes = <TwoFingerSwipeDirection>[];
    await pumpDetector(tester, swipes);

    final first = TestPointer(1, PointerDeviceKind.touch);
    final second = TestPointer(2, PointerDeviceKind.touch);
    final third = TestPointer(3, PointerDeviceKind.touch);
    await tester.sendEventToBinding(first.down(const Offset(240, 320)));
    await tester.sendEventToBinding(second.down(const Offset(320, 320)));
    await tester.sendEventToBinding(third.down(const Offset(400, 320)));
    await tester.sendEventToBinding(first.move(const Offset(150, 320)));
    await tester.sendEventToBinding(second.move(const Offset(230, 320)));
    await tester.pump();

    expect(swipes, isEmpty);
  });
}
