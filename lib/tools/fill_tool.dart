import 'dart:ui';

import '../core/document/pixel_buffer.dart';
import '../core/geometry/flood_fill.dart';
import '../core/geometry/point.dart';
import '../input/input_controller.dart';

/// Fill bucket tool for flood filling connected regions.
///
/// Supports:
/// - Scanline flood fill algorithm for efficient filling
/// - Color tolerance for filling similar colors
/// - Contiguous mode (fill connected pixels) vs global mode (fill all matching)
class FillTool {
  /// Fill color.
  Color color;

  /// Color tolerance for matching (0-255).
  int tolerance;

  /// Whether to fill only contiguous pixels.
  bool contiguous;

  /// Callback when pixels should be filled.
  final void Function(List<Point> pixels, int fillColor)? onFill;

  /// Access to the pixel buffer for reading colors.
  final PixelBuffer Function()? getBuffer;

  /// Current tool state.
  ToolState _state = ToolState.idle;

  FillTool({
    this.color = const Color(0xFF000000),
    this.tolerance = 0,
    this.contiguous = true,
    this.onFill,
    this.getBuffer,
  });

  /// Current tool state.
  ToolState get state => _state;

  /// Handle input event from InputController.
  void handleInput(CanvasInputEvent event) {
    switch (event.type) {
      case InputEventType.down:
        onStart(event.point);
      case InputEventType.move:
      case InputEventType.up:
      case InputEventType.cancel:
      case InputEventType.hover:
        // Fill tool only acts on down
        break;
    }
  }

  /// Perform fill on click.
  void onStart(CanvasPoint point) {
    _state = ToolState.active;

    final buffer = getBuffer?.call();
    if (buffer == null) {
      _state = ToolState.idle;
      return;
    }

    final x = point.x.round();
    final y = point.y.round();

    // Bounds check
    if (!buffer.contains(x, y)) {
      _state = ToolState.idle;
      return;
    }

    final fillColor = _colorToInt(color);
    final targetColor = buffer.getPixelRaw(x, y);

    // Don't fill if colors are the same
    if (_colorsMatch(targetColor, fillColor, 0)) {
      _state = ToolState.idle;
      return;
    }

    List<Point> filled;
    if (contiguous) {
      filled = FloodFill.fill(
        buffer: buffer,
        start: Point(x, y),
        fillColor: fillColor,
        tolerance: tolerance,
      );
    } else {
      filled = _fillGlobal(buffer, targetColor, fillColor);
    }

    if (filled.isNotEmpty) {
      onFill?.call(filled, fillColor);
    }

    _state = ToolState.idle;
  }

  /// Fills all matching pixels globally (non-contiguous).
  List<Point> _fillGlobal(PixelBuffer buffer, int targetColor, int fillColor) {
    final filled = <Point>[];

    for (var y = 0; y < buffer.height; y++) {
      for (var x = 0; x < buffer.width; x++) {
        final color = buffer.getPixelRaw(x, y);
        if (_colorsMatch(color, targetColor, tolerance)) {
          buffer.setPixelRaw(x, y, fillColor);
          filled.add(Point(x, y));
        }
      }
    }

    return filled;
  }

  /// Converts Color to packed int (RGBA).
  int _colorToInt(Color c) {
    return (c.red << 24) | (c.green << 16) | (c.blue << 8) | c.alpha;
  }

  /// Checks if two colors match within tolerance.
  bool _colorsMatch(int a, int b, int tol) {
    if (tol == 0) return a == b;

    final aR = (a >> 24) & 0xFF;
    final aG = (a >> 16) & 0xFF;
    final aB = (a >> 8) & 0xFF;
    final aA = a & 0xFF;

    final bR = (b >> 24) & 0xFF;
    final bG = (b >> 16) & 0xFF;
    final bB = (b >> 8) & 0xFF;
    final bA = b & 0xFF;

    return (aR - bR).abs() <= tol &&
        (aG - bG).abs() <= tol &&
        (aB - bB).abs() <= tol &&
        (aA - bA).abs() <= tol;
  }
}

/// Tool state for FillTool.
enum ToolState {
  idle,
  active,
}
