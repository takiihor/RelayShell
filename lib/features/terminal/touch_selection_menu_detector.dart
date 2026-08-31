import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Reports the end of a deliberate touch long-press without competing with
/// the terminal's own selection recognizer.
class TouchSelectionMenuDetector extends StatefulWidget {
  const TouchSelectionMenuDetector({
    required this.child,
    required this.onLongPressEnd,
    super.key,
  });

  final Widget child;
  final VoidCallback onLongPressEnd;

  @override
  State<TouchSelectionMenuDetector> createState() =>
      _TouchSelectionMenuDetectorState();
}

class _TouchSelectionMenuDetectorState
    extends State<TouchSelectionMenuDetector> {
  final _touchPointers = <int>{};
  int? _primaryPointer;
  Offset? _start;
  Duration? _downTime;
  var _blocked = false;

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touchPointers.add(event.pointer);

    if (_touchPointers.length != 1) {
      _cancelTracking(blockUntilClear: true);
      return;
    }

    _primaryPointer = event.pointer;
    _start = event.position;
    _downTime = event.timeStamp;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_blocked || event.pointer != _primaryPointer) return;
    final start = _start;
    if (!_heldLongEnough(event.timeStamp) &&
        start != null &&
        (event.position - start).distance > kTouchSlop) {
      _cancelTracking();
    }
  }

  void _onPointerEnd(PointerEvent event) {
    final shouldOpen =
        !_blocked &&
        event.pointer == _primaryPointer &&
        _heldLongEnough(event.timeStamp);
    _touchPointers.remove(event.pointer);

    if (_touchPointers.isEmpty) {
      _cancelTracking();
      _blocked = false;
    } else if (event.pointer == _primaryPointer) {
      _cancelTracking(blockUntilClear: true);
    }

    if (shouldOpen) {
      widget.onLongPressEnd();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touchPointers.remove(event.pointer);
    _cancelTracking(blockUntilClear: _touchPointers.isNotEmpty);
    if (_touchPointers.isEmpty) _blocked = false;
  }

  bool _heldLongEnough(Duration eventTime) {
    final downTime = _downTime;
    return downTime != null && eventTime - downTime >= kLongPressTimeout;
  }

  void _cancelTracking({bool blockUntilClear = false}) {
    _primaryPointer = null;
    _start = null;
    _downTime = null;
    if (blockUntilClear) _blocked = true;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: _onPointerEnd,
    onPointerCancel: _onPointerCancel,
    child: widget.child,
  );
}
