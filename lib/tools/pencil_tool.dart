import 'dart:math' as math;
import 'dart:ui';

import '../input/input_controller.dart';

/// A pencil tool that draws pixels along the stroke path.
///
/// Features:
/// - Bresenham line interpolation between points
/// - Pressure sensitivity for size/opacity
/// - Configurable brush size (1-64 pixels)
class PencilTool {
  /// Current brush color (ARGB).
  Color color;

  /// Base brush size in pixels.
  int size;

  /// Whether pressure affects brush size.
  bool pressureAffectsSize;

  /// Whether pressure affects opacity.
  bool pressureAffectsOpacity;

  /// Minimum size multiplier at zero pressure.
  double minPressureSize;

  /// Minimum opacity multiplier at zero pressure.
  double minPressureOpacity;

  /// Callback when pixels should be drawn.
  final void Function(List<PixelDraw> pixels)? onDraw;

  /// Current tool state.
  ToolState _state = ToolState.idle;

  /// Last drawn point for interpolation.
  CanvasPoint? _lastPoint;

  PencilTool({
    this.color = const Color(0xFF000000),
    this.size = 1,
    this.pressureAffectsSize = true,
    this.pressureAffectsOpacity = false,
    this.minPressureSize = 0.25,
    this.minPressureOpacity = 0.5,
    this.onDraw,
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
        // Pencil doesn't respond to hover
        break;
    }
  }

  /// Start a new stroke.
  void onStart(CanvasPoint point) {
    _state = ToolState.active;
    _lastPoint = point;

    // Draw initial point
    final pixels = _drawPoint(point);
    if (pixels.isNotEmpty) {
      onDraw?.call(pixels);
    }
  }

  /// Continue the stroke.
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
      onDraw?.call(pixels);
    }

    _lastPoint = point;
  }

  /// End the stroke.
  void onEnd(CanvasPoint point) {
    if (_state != ToolState.active) return;

    // Draw final segment
    final lastPoint = _lastPoint;
    if (lastPoint != null) {
      final pixels = _interpolateStroke(lastPoint, point);
      if (pixels.isNotEmpty) {
        onDraw?.call(pixels);
      }
    }

    _state = ToolState.idle;
    _lastPoint = null;
  }

  /// Cancel the stroke.
  void onCancel() {
    _state = ToolState.idle;
    _lastPoint = null;
  }

  /// Draw a single point with the current brush.
  List<PixelDraw> _drawPoint(CanvasPoint point) {
    final effectiveSize = _calculateSize(point.pressure);
    final effectiveColor = _calculateColor(point.pressure);

    return _drawBrush(point.pixelX, point.pixelY, effectiveSize, effectiveColor);
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
      final effectiveColor = _calculateColor(pressure);

      pixels.addAll(_drawBrush(x, y, effectiveSize, effectiveColor));

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

  /// Draw a brush stamp at the given position.
  List<PixelDraw> _drawBrush(int cx, int cy, int brushSize, Color brushColor) {
    final pixels = <PixelDraw>[];

    if (brushSize <= 1) {
      // Single pixel
      pixels.add(PixelDraw(x: cx, y: cy, color: brushColor));
    } else {
      // Circular brush
      final radius = brushSize ~/ 2;
      final radiusSq = radius * radius;

      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dy * dy <= radiusSq) {
            pixels.add(PixelDraw(
              x: cx + dx,
              y: cy + dy,
              color: brushColor,
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

  Color _calculateColor(double pressure) {
    if (!pressureAffectsOpacity) return color;

    final factor = minPressureOpacity + (1.0 - minPressureOpacity) * pressure;
    final currentAlpha = (color.a * 255.0).round();
    final newAlpha = (currentAlpha * factor).round().clamp(0, 255);
    return color.withAlpha(newAlpha);
  }
}

/// Represents a pixel to be drawn.
class PixelDraw {
  final int x;
  final int y;
  final Color color;

  const PixelDraw({
    required this.x,
    required this.y,
    required this.color,
  });
}

/// Tool state enum.
enum ToolState {
  /// Tool is not active.
  idle,

  /// Tool is actively drawing.
  active,

  /// Tool is showing a preview.
  previewing,
}
