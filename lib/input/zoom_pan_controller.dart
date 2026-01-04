import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../rendering/canvas_transform.dart';

/// Controller for handling zoom and pan gestures on the canvas.
///
/// Wraps a [CanvasTransform] and provides gesture detection for:
/// - Pinch-to-zoom (multi-touch scale gesture)
/// - Two-finger pan
/// - Mouse wheel zoom
/// - Scroll/trackpad pan
class ZoomPanController {
  /// The underlying canvas transform.
  final CanvasTransform transform;

  /// Callback when a drawing gesture might start (single finger/click down).
  final VoidCallback? onDrawStart;

  /// Whether panning requires two fingers (true) or allows single finger (false).
  final bool twoFingerPan;

  /// Zoom factor per mouse wheel notch.
  final double wheelZoomFactor;

  /// Current gesture state.
  _GestureState _state = _GestureState.idle;

  /// Number of active pointers.
  int _pointerCount = 0;

  /// Focal point at gesture start for scale operations.
  Offset? _initialFocalPoint;

  /// Scale at gesture start.
  double? _initialScale;

  ZoomPanController({
    required this.transform,
    this.onDrawStart,
    this.twoFingerPan = true,
    this.wheelZoomFactor = 1.1,
  });

  /// Build a gesture detector widget that handles zoom/pan.
  Widget buildGestureDetector({required Widget child}) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,
        child: child,
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerCount++;

    if (_pointerCount == 1 && twoFingerPan) {
      // Single finger - potential draw gesture
      _state = _GestureState.potentialDraw;
    } else if (_pointerCount >= 2) {
      // Two+ fingers - definitely zoom/pan
      _state = _GestureState.zoomPan;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    if (_pointerCount == 0) {
      _state = _GestureState.idle;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    if (_pointerCount == 0) {
      _state = _GestureState.idle;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Check for pinch-to-zoom on trackpad (scale gesture via scroll)
      if (event.kind == PointerDeviceKind.trackpad) {
        // Trackpad scroll - pan
        transform.panBy(Offset(-event.scrollDelta.dx, -event.scrollDelta.dy));
      } else {
        // Mouse wheel - zoom
        final zoomFactor = event.scrollDelta.dy > 0
            ? 1 / wheelZoomFactor
            : wheelZoomFactor;
        transform.zoomBy(zoomFactor, focalPoint: event.localPosition);
      }
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _initialFocalPoint = details.localFocalPoint;
    _initialScale = transform.zoom;

    if (_pointerCount == 1 && twoFingerPan) {
      // Single finger - might be drawing
      onDrawStart?.call();
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_pointerCount >= 2 || !twoFingerPan) {
      // Handle zoom
      if (details.scale != 1.0 && _initialScale != null) {
        final newZoom = _initialScale! * details.scale;
        transform.setZoom(newZoom, focalPoint: details.localFocalPoint);
      }

      // Handle pan
      if (_initialFocalPoint != null) {
        final delta = details.localFocalPoint - _initialFocalPoint!;
        transform.panBy(delta);
        _initialFocalPoint = details.localFocalPoint;
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _initialFocalPoint = null;
    _initialScale = null;

    // Could add momentum/fling physics here
    // final velocity = details.velocity.pixelsPerSecond;
  }

  /// Programmatically zoom to a specific level with animation.
  void zoomTo(double zoom, {Offset? focalPoint}) {
    transform.setZoom(zoom, focalPoint: focalPoint);
  }

  /// Zoom in by one step (2x).
  void zoomIn({Offset? focalPoint}) {
    transform.zoomBy(2.0, focalPoint: focalPoint);
  }

  /// Zoom out by one step (0.5x).
  void zoomOut({Offset? focalPoint}) {
    transform.zoomBy(0.5, focalPoint: focalPoint);
  }

  /// Reset to 1x zoom.
  void resetZoom() {
    transform.reset();
  }

  /// Fit canvas to viewport.
  void fitToView() {
    transform.fitToView();
  }

  /// Current zoom level.
  double get zoom => transform.zoom;

  /// Whether currently in a zoom/pan gesture.
  bool get isZoomPanning => _state == _GestureState.zoomPan;
}

enum _GestureState {
  idle,
  potentialDraw,
  zoomPan,
}

/// A widget that provides zoom/pan functionality for its child.
///
/// Wraps the child with gesture detection and transformation.
class ZoomPanView extends StatefulWidget {
  /// The canvas transform to use.
  final CanvasTransform transform;

  /// The child widget (typically the canvas).
  final Widget child;

  /// Whether panning requires two fingers.
  final bool twoFingerPan;

  /// Callback when a potential draw gesture starts.
  final VoidCallback? onDrawStart;

  const ZoomPanView({
    super.key,
    required this.transform,
    required this.child,
    this.twoFingerPan = true,
    this.onDrawStart,
  });

  @override
  State<ZoomPanView> createState() => _ZoomPanViewState();
}

class _ZoomPanViewState extends State<ZoomPanView> {
  late ZoomPanController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ZoomPanController(
      transform: widget.transform,
      onDrawStart: widget.onDrawStart,
      twoFingerPan: widget.twoFingerPan,
    );
  }

  @override
  void didUpdateWidget(ZoomPanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transform != widget.transform ||
        oldWidget.twoFingerPan != widget.twoFingerPan) {
      _controller = ZoomPanController(
        transform: widget.transform,
        onDrawStart: widget.onDrawStart,
        twoFingerPan: widget.twoFingerPan,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Update viewport size when layout changes
        widget.transform.setViewportSize(constraints.biggest);

        return _controller.buildGestureDetector(
          child: ListenableBuilder(
            listenable: widget.transform,
            builder: (context, _) {
              return Transform(
                transform: widget.transform.matrix,
                child: widget.child,
              );
            },
          ),
        );
      },
    );
  }
}
