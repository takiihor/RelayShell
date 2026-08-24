import 'dart:ui';

import 'package:flutter/widgets.dart';

/// The direction of an intentional two-finger terminal-tab swipe.
enum TwoFingerSwipeDirection { left, right }

/// Reports deliberate two-finger horizontal swipes without claiming normal
/// terminal touch input, such as scrolling and text selection.
class TwoFingerSwipeDetector extends StatefulWidget {
  const TwoFingerSwipeDetector({
    required this.child,
    required this.onSwipe,
    super.key,
  });

  final Widget child;
  final ValueChanged<TwoFingerSwipeDirection> onSwipe;

  @override
  State<TwoFingerSwipeDetector> createState() => _TwoFingerSwipeDetectorState();
}

class _TwoFingerSwipeDetectorState extends State<TwoFingerSwipeDetector> {
  static const _minimumDistance = 72.0;
  static const _minimumFingerDistance = 36.0;
  static const _maximumVerticalDistance = 48.0;

  final _starts = <int, Offset>{};
  final _positions = <int, Offset>{};
  var _tracking = false;
  var _recognized = false;

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _starts[event.pointer] = event.position;
    _positions[event.pointer] = event.position;

    if (_starts.length == 2) {
      _starts
        ..clear()
        ..addAll(_positions);
      _tracking = true;
      _recognized = false;
    } else if (_starts.length > 2) {
      _tracking = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_positions.containsKey(event.pointer)) return;
    _positions[event.pointer] = event.position;
    if (!_tracking || _recognized || _starts.length != 2) return;

    final pointers = _starts.keys.toList(growable: false);
    final first = _positions[pointers[0]]! - _starts[pointers[0]]!;
    final second = _positions[pointers[1]]! - _starts[pointers[1]]!;
    final averageX = (first.dx + second.dx) / 2;

    if (first.dx.abs() < _minimumFingerDistance ||
        second.dx.abs() < _minimumFingerDistance ||
        first.dx.sign != second.dx.sign ||
        first.dy.abs() > _maximumVerticalDistance ||
        second.dy.abs() > _maximumVerticalDistance ||
        averageX.abs() < _minimumDistance) {
      return;
    }

    _recognized = true;
    widget.onSwipe(
      averageX.isNegative
          ? TwoFingerSwipeDirection.left
          : TwoFingerSwipeDirection.right,
    );
  }

  void _onPointerEnd(PointerEvent event) {
    _starts.remove(event.pointer);
    _positions.remove(event.pointer);
    if (_starts.isEmpty) {
      _tracking = false;
      _recognized = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: _onPointerEnd,
    onPointerCancel: _onPointerEnd,
    child: widget.child,
  );
}
