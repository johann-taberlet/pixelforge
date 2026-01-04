import 'dart:math' as math;

import 'shape_tool.dart';

/// Tool for drawing rectangles.
///
/// Features:
/// - Outline or filled rectangles
/// - Shift-constrain for perfect squares
/// - Preview overlay during drag
class RectangleTool extends AspectRatioShapeTool {
  @override
  String get id => 'rectangle';

  @override
  String get name => 'Rectangle';

  @override
  List<PixelPoint> computeShapePixels(int x1, int y1, int x2, int y2) {
    // Normalize coordinates so x1,y1 is top-left
    final left = math.min(x1, x2);
    final right = math.max(x1, x2);
    final top = math.min(y1, y2);
    final bottom = math.max(y1, y2);

    if (filled) {
      return _filledRectangle(left, top, right, bottom);
    } else {
      return _outlineRectangle(left, top, right, bottom);
    }
  }

  /// Generate pixels for a filled rectangle.
  List<PixelPoint> _filledRectangle(int left, int top, int right, int bottom) {
    final pixels = <PixelPoint>[];

    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        pixels.add(PixelPoint(x, y));
      }
    }

    return pixels;
  }

  /// Generate pixels for a rectangle outline (1 pixel thick).
  List<PixelPoint> _outlineRectangle(int left, int top, int right, int bottom) {
    final pixels = <PixelPoint>[];

    // Top edge
    for (var x = left; x <= right; x++) {
      pixels.add(PixelPoint(x, top));
    }

    // Bottom edge
    if (bottom != top) {
      for (var x = left; x <= right; x++) {
        pixels.add(PixelPoint(x, bottom));
      }
    }

    // Left edge (excluding corners already added)
    for (var y = top + 1; y < bottom; y++) {
      pixels.add(PixelPoint(left, y));
    }

    // Right edge (excluding corners already added)
    if (right != left) {
      for (var y = top + 1; y < bottom; y++) {
        pixels.add(PixelPoint(right, y));
      }
    }

    return pixels;
  }
}
