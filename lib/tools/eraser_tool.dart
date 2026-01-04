import 'dart:math' as math;
import 'dart:ui';

import '../input/input_controller.dart';
import 'pencil_tool.dart';

/// An eraser tool that sets pixels to transparent.
///
/// Features:
/// - Bresenham line interpolation between points
/// - Pressure sensitivity for eraser size
/// - Configurable eraser size (1-64 pixels)
/// - Hard or soft edge modes
class EraserTool {
  /// Base eraser size in pixels.
  int size;

  /// Whether pressure affects eraser size.
  bool pressureAffectsSize;

  /// Minimum size multiplier at zero pressure.
  double minPressureSize;

  /// Whether to use soft edges (gradual alpha falloff).
  bool softEdge;

  /// Callback when pixels should be erased.
  final void Function(List<PixelDraw> pixels)? onErase;

  /// Current tool state.
  ToolState _state = ToolState.idle;

  /// Last erased point for interpolation.
  CanvasPoint? _lastPoint;

  /// Transparent color for erasing.
  static const Color _transparent = Color(0x00000000);

  EraserTool({
    this.size = 8,
    this.pressureAffectsSize = true,
    this.minPressureSize = 0.25,
    this.softEdge = false,
    this.onErase,
  });

  /// Current tool state.
  ToolState get state => _state;

  /// Handle input event from InputController.
  void handleInput(CanvasInputEvent event) {
    switch (event.type) {
      case InputEventType.down:
        onStart(event.point);
      case InputEventType.move:
        onUpdate(event.point);
      case InputEventType.up:
        onEnd(event.point);
      case InputEventType.cancel:
        onCancel();
      case InputEventType.hover:
        // Eraser doesn't respond to hover
        break;
    }
  }

  /// Start erasing.
  void onStart(CanvasPoint point) {
    _state = ToolState.active;
    _lastPoint = point;

    // Erase initial point
    final pixels = _erasePoint(point);
    if (pixels.isNotEmpty) {
      onErase?.call(pixels);
    }
  }

  /// Continue erasing.
  void onUpdate(CanvasPoint point) {
    if (_state != ToolState.active) return;

    final lastPoint = _lastPoint;
    if (lastPoint == null) {
      _lastPoint = point;
      return;
    }

    // Interpolate between last point and current point
    final pixels = _interpolateStroke(lastPoint, point);
    if (pixels.isNotEmpty) {
      onErase?.call(pixels);
    }

    _lastPoint = point;
  }

  /// End erasing.
  void onEnd(CanvasPoint point) {
    if (_state != ToolState.active) return;

    // Erase final segment
    final lastPoint = _lastPoint;
    if (lastPoint != null) {
      final pixels = _interpolateStroke(lastPoint, point);
      if (pixels.isNotEmpty) {
        onErase?.call(pixels);
      }
    }

    _state = ToolState.idle;
    _lastPoint = null;
  }

  /// Cancel erasing.
  void onCancel() {
    _state = ToolState.idle;
    _lastPoint = null;
  }

  /// Erase a single point with the current brush.
  List<PixelDraw> _erasePoint(CanvasPoint point) {
    final effectiveSize = _calculateSize(point.pressure);
    return _drawBrush(point.pixelX, point.pixelY, effectiveSize);
  }

  /// Interpolate stroke between two points using Bresenham's algorithm.
  List<PixelDraw> _interpolateStroke(CanvasPoint from, CanvasPoint to) {
    final pixels = <PixelDraw>[];

    final x0 = from.pixelX;
    final y0 = from.pixelY;
    final x1 = to.pixelX;
    final y1 = to.pixelY;

    final dx = (x1 - x0).abs();
    final dy = (y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx - dy;

    var x = x0;
    var y = y0;

    // Interpolate pressure along the stroke
    final steps = math.max(dx, dy);
    var step = 0;

    while (true) {
      // Interpolate pressure
      final t = steps > 0 ? step / steps : 1.0;
      final pressure = from.pressure + (to.pressure - from.pressure) * t;

      final effectiveSize = _calculateSize(pressure);
      pixels.addAll(_drawBrush(x, y, effectiveSize));

      if (x == x1 && y == y1) break;

      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
      step++;
    }

    return pixels;
  }

  /// Draw an eraser stamp at the given position.
  List<PixelDraw> _drawBrush(int cx, int cy, int brushSize) {
    final pixels = <PixelDraw>[];

    if (brushSize <= 1) {
      // Single pixel
      pixels.add(PixelDraw(x: cx, y: cy, color: _transparent));
    } else {
      // Circular brush
      final radius = brushSize ~/ 2;
      final radiusSq = radius * radius;

      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final distSq = dx * dx + dy * dy;
          if (distSq <= radiusSq) {
            Color eraseColor;

            if (softEdge && radius > 1) {
              // Soft edge: gradual alpha falloff
              final dist = math.sqrt(distSq.toDouble());
              final falloff = 1.0 - (dist / radius);
              final alpha = (falloff * 255).round().clamp(0, 255);
              // Erasing with partial alpha blends toward transparency
              eraseColor = Color.fromARGB(alpha, 0, 0, 0);
            } else {
              eraseColor = _transparent;
            }

            pixels.add(PixelDraw(
              x: cx + dx,
              y: cy + dy,
              color: eraseColor,
            ));
          }
        }
      }
    }

    return pixels;
  }

  int _calculateSize(double pressure) {
    if (!pressureAffectsSize || size <= 1) return size;

    final factor = minPressureSize + (1.0 - minPressureSize) * pressure;
    return (size * factor).round().clamp(1, 64);
  }
}
