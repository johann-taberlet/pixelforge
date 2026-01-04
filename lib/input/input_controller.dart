import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../rendering/canvas_transform.dart';

/// Represents a point in canvas coordinate space.
class CanvasPoint {
  /// X coordinate in canvas pixels.
  final double x;

  /// Y coordinate in canvas pixels.
  final double y;

  /// Pressure from stylus (0.0 to 1.0, 1.0 for non-pressure devices).
  final double pressure;

  /// Whether this point is from a stylus.
  final bool isStylus;

  const CanvasPoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.isStylus = false,
  });

  /// Integer pixel coordinates.
  int get pixelX => x.floor();
  int get pixelY => y.floor();

  Offset get offset => Offset(x, y);

  @override
  String toString() => 'CanvasPoint($x, $y, pressure: $pressure)';
}

/// Event types that can be routed to tools.
enum InputEventType {
  /// Pointer/finger down - start of a stroke.
  down,

  /// Pointer/finger moved - continuing a stroke.
  move,

  /// Pointer/finger up - end of a stroke.
  up,

  /// Pointer cancelled (e.g., palm rejection).
  cancel,

  /// Hover without touching (stylus proximity).
  hover,
}

/// An input event in canvas space, ready to be processed by a tool.
class CanvasInputEvent {
  /// The type of input event.
  final InputEventType type;

  /// The point in canvas coordinates.
  final CanvasPoint point;

  /// Pointer ID for multi-touch tracking.
  final int pointerId;

  /// Timestamp of the event.
  final Duration timestamp;

  /// The raw pointer event (for advanced use).
  final PointerEvent? rawEvent;

  const CanvasInputEvent({
    required this.type,
    required this.point,
    required this.pointerId,
    required this.timestamp,
    this.rawEvent,
  });

  @override
  String toString() => 'CanvasInputEvent($type, $point, pointer: $pointerId)';
}

/// Callback signature for tool input events.
typedef ToolInputCallback = void Function(CanvasInputEvent event);

/// Callback signature for batch input events (for coalescing).
typedef ToolBatchInputCallback = void Function(List<CanvasInputEvent> events);

/// Controller for handling input events and routing them to tools.
///
/// Provides:
/// - RepaintBoundary wrapping for render isolation
/// - GestureDetector for pan/scale/tap events
/// - Coordinate transform from screen to canvas space
/// - Event routing to the active tool
class InputController {
  /// The canvas transform for coordinate conversion.
  final CanvasTransform transform;

  /// Callback for individual input events.
  ToolInputCallback? onInput;

  /// Callback for batched input events (called on frame boundary).
  ToolBatchInputCallback? onBatchInput;

  /// Whether input is currently enabled.
  bool enabled = true;

  /// Minimum distance (in canvas pixels) to trigger a move event.
  double moveThreshold = 0.5;

  /// Active pointers being tracked.
  final Map<int, CanvasPoint> _activePointers = {};

  /// Pending events for batch delivery.
  final List<CanvasInputEvent> _pendingEvents = [];

  /// Last delivered point per pointer (for move threshold).
  final Map<int, CanvasPoint> _lastDeliveredPoints = {};

  InputController({
    required this.transform,
    this.onInput,
    this.onBatchInput,
  });

  /// Build a widget that captures input and wraps the child in RepaintBoundary.
  Widget buildInputLayer({required Widget child}) {
    return RepaintBoundary(
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        onPointerHover: _handlePointerHover,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }

  /// Convert a screen position to canvas coordinates.
  CanvasPoint screenToCanvas(
    Offset screenPosition, {
    double pressure = 1.0,
    bool isStylus = false,
  }) {
    final canvasOffset = transform.screenToCanvas(screenPosition);
    return CanvasPoint(
      x: canvasOffset.dx,
      y: canvasOffset.dy,
      pressure: pressure,
      isStylus: isStylus,
    );
  }

  /// Get the current position of a tracked pointer.
  CanvasPoint? getPointerPosition(int pointerId) {
    return _activePointers[pointerId];
  }

  /// Check if a pointer is currently active.
  bool isPointerActive(int pointerId) {
    return _activePointers.containsKey(pointerId);
  }

  /// Number of active pointers.
  int get activePointerCount => _activePointers.length;

  /// Flush any pending batched events.
  void flushPendingEvents() {
    if (_pendingEvents.isNotEmpty && onBatchInput != null) {
      onBatchInput!(_pendingEvents.toList());
      _pendingEvents.clear();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!enabled) return;

    final point = _createCanvasPoint(event);
    _activePointers[event.pointer] = point;
    _lastDeliveredPoints[event.pointer] = point;

    _deliverEvent(CanvasInputEvent(
      type: InputEventType.down,
      point: point,
      pointerId: event.pointer,
      timestamp: event.timeStamp,
      rawEvent: event,
    ));
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!enabled) return;
    if (!_activePointers.containsKey(event.pointer)) return;

    final point = _createCanvasPoint(event);
    _activePointers[event.pointer] = point;

    // Check move threshold to avoid excessive events
    final lastPoint = _lastDeliveredPoints[event.pointer];
    if (lastPoint != null) {
      final dx = point.x - lastPoint.x;
      final dy = point.y - lastPoint.y;
      final distance = dx * dx + dy * dy;
      if (distance < moveThreshold * moveThreshold) {
        return; // Below threshold, skip this event
      }
    }

    _lastDeliveredPoints[event.pointer] = point;

    _deliverEvent(CanvasInputEvent(
      type: InputEventType.move,
      point: point,
      pointerId: event.pointer,
      timestamp: event.timeStamp,
      rawEvent: event,
    ));
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!enabled) return;

    final point = _createCanvasPoint(event);
    _activePointers.remove(event.pointer);
    _lastDeliveredPoints.remove(event.pointer);

    _deliverEvent(CanvasInputEvent(
      type: InputEventType.up,
      point: point,
      pointerId: event.pointer,
      timestamp: event.timeStamp,
      rawEvent: event,
    ));
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!enabled) return;

    final point = _activePointers[event.pointer] ??
        CanvasPoint(x: 0, y: 0);
    _activePointers.remove(event.pointer);
    _lastDeliveredPoints.remove(event.pointer);

    _deliverEvent(CanvasInputEvent(
      type: InputEventType.cancel,
      point: point,
      pointerId: event.pointer,
      timestamp: event.timeStamp,
      rawEvent: event,
    ));
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (!enabled) return;

    final point = _createCanvasPoint(event);

    _deliverEvent(CanvasInputEvent(
      type: InputEventType.hover,
      point: point,
      pointerId: event.pointer,
      timestamp: event.timeStamp,
      rawEvent: event,
    ));
  }

  CanvasPoint _createCanvasPoint(PointerEvent event) {
    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    return screenToCanvas(
      event.localPosition,
      pressure: event.pressure,
      isStylus: isStylus,
    );
  }

  void _deliverEvent(CanvasInputEvent event) {
    // Immediate delivery
    onInput?.call(event);

    // Batch collection (flushed by caller or frame boundary)
    if (onBatchInput != null) {
      _pendingEvents.add(event);
    }
  }

  /// Cancel all active pointers (e.g., when switching tools).
  void cancelAllPointers() {
    final timestamp = Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch,
    );

    for (final entry in _activePointers.entries) {
      _deliverEvent(CanvasInputEvent(
        type: InputEventType.cancel,
        point: entry.value,
        pointerId: entry.key,
        timestamp: timestamp,
      ));
    }

    _activePointers.clear();
    _lastDeliveredPoints.clear();
  }
}

/// A widget that provides input handling for a canvas.
///
/// Wraps the child with input detection, coordinate transformation,
/// and RepaintBoundary isolation.
class CanvasInputLayer extends StatefulWidget {
  /// The canvas transform for coordinate conversion.
  final CanvasTransform transform;

  /// The child widget (the canvas).
  final Widget child;

  /// Callback for input events.
  final ToolInputCallback? onInput;

  /// Whether input is enabled.
  final bool enabled;

  const CanvasInputLayer({
    super.key,
    required this.transform,
    required this.child,
    this.onInput,
    this.enabled = true,
  });

  @override
  State<CanvasInputLayer> createState() => _CanvasInputLayerState();
}

class _CanvasInputLayerState extends State<CanvasInputLayer> {
  late InputController _controller;

  @override
  void initState() {
    super.initState();
    _controller = InputController(
      transform: widget.transform,
      onInput: widget.onInput,
    );
    _controller.enabled = widget.enabled;
  }

  @override
  void didUpdateWidget(CanvasInputLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.onInput = widget.onInput;
    _controller.enabled = widget.enabled;

    if (oldWidget.transform != widget.transform) {
      _controller = InputController(
        transform: widget.transform,
        onInput: widget.onInput,
      );
      _controller.enabled = widget.enabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _controller.buildInputLayer(child: widget.child);
  }
}
