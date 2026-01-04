import 'dart:math' as math;

import 'shape_tool.dart';

/// Tool for drawing ellipses and circles.
///
/// Features:
/// - Midpoint ellipse algorithm for pixel-perfect curves
/// - Outline or filled ellipses
/// - Shift-constrain for perfect circles
/// - Preview overlay during drag
class EllipseTool extends AspectRatioShapeTool {
  @override
  String get id => 'ellipse';

  @override
  String get name => 'Ellipse';

  @override
  List<PixelPoint> computeShapePixels(int x1, int y1, int x2, int y2) {
    // Calculate center and radii from bounding box
    final left = math.min(x1, x2);
    final right = math.max(x1, x2);
    final top = math.min(y1, y2);
    final bottom = math.max(y1, y2);

    final cx = (left + right) ~/ 2;
    final cy = (top + bottom) ~/ 2;
    final rx = (right - left) ~/ 2;
    final ry = (bottom - top) ~/ 2;

    if (rx == 0 || ry == 0) {
      // Degenerate case: single point or line
      return [PixelPoint(cx, cy)];
    }

    if (filled) {
      return _filledEllipse(cx, cy, rx, ry);
    } else {
      return _outlineEllipse(cx, cy, rx, ry);
    }
  }

  /// Generate pixels for an ellipse outline using the midpoint algorithm.
  List<PixelPoint> _outlineEllipse(int cx, int cy, int rx, int ry) {
    final pixels = <PixelPoint>[];

    // Midpoint ellipse algorithm
    var x = 0;
    var y = ry;

    // Precompute squares
    final rx2 = rx * rx;
    final ry2 = ry * ry;
    final twoRx2 = 2 * rx2;
    final twoRy2 = 2 * ry2;

    // Region 1: dy/dx >= -1
    var px = 0;
    var py = twoRx2 * y;

    // Initial decision parameter
    var p1 = ry2 - (rx2 * ry) + (0.25 * rx2);

    while (px < py) {
      _addEllipsePoints(pixels, cx, cy, x, y);

      x++;
      px += twoRy2;

      if (p1 < 0) {
        p1 += ry2 + px;
      } else {
        y--;
        py -= twoRx2;
        p1 += ry2 + px - py;
      }
    }

    // Region 2: dy/dx < -1
    var p2 = ry2 * (x + 0.5) * (x + 0.5) +
        rx2 * (y - 1) * (y - 1) -
        rx2 * ry2;

    while (y >= 0) {
      _addEllipsePoints(pixels, cx, cy, x, y);

      y--;
      py -= twoRx2;

      if (p2 > 0) {
        p2 += rx2 - py;
      } else {
        x++;
        px += twoRy2;
        p2 += rx2 - py + px;
      }
    }

    return pixels;
  }

  /// Add the four symmetric points of an ellipse.
  void _addEllipsePoints(
    List<PixelPoint> pixels,
    int cx,
    int cy,
    int x,
    int y,
  ) {
    pixels.add(PixelPoint(cx + x, cy + y));
    pixels.add(PixelPoint(cx - x, cy + y));
    pixels.add(PixelPoint(cx + x, cy - y));
    pixels.add(PixelPoint(cx - x, cy - y));
  }

  /// Generate pixels for a filled ellipse.
  List<PixelPoint> _filledEllipse(int cx, int cy, int rx, int ry) {
    final pixels = <PixelPoint>[];

    // Use scanline fill approach
    for (var y = -ry; y <= ry; y++) {
      // Calculate x extent at this y using ellipse equation
      // (x/rx)^2 + (y/ry)^2 = 1
      // x = rx * sqrt(1 - (y/ry)^2)
      final yNorm = y.toDouble() / ry;
      final xExtent = (rx * math.sqrt(1 - yNorm * yNorm)).round();

      for (var x = -xExtent; x <= xExtent; x++) {
        pixels.add(PixelPoint(cx + x, cy + y));
      }
    }

    return pixels;
  }
}
