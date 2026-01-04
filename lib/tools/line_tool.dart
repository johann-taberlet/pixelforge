import 'shape_tool.dart';

/// Tool for drawing straight lines.
///
/// Features:
/// - Bresenham's algorithm for pixel-perfect lines
/// - Shift-constrain for 45-degree angle snapping
/// - Preview overlay during drag
class LineTool extends AngleConstrainedShapeTool {
  @override
  String get id => 'line';

  @override
  String get name => 'Line';

  @override
  List<PixelPoint> computeShapePixels(int x1, int y1, int x2, int y2) {
    return bresenhamLine(x1, y1, x2, y2);
  }

  /// Bresenham's line algorithm.
  ///
  /// Draws a line from (x1, y1) to (x2, y2) using only integer arithmetic.
  /// Returns a list of all pixel coordinates on the line.
  static List<PixelPoint> bresenhamLine(int x1, int y1, int x2, int y2) {
    final pixels = <PixelPoint>[];

    var dx = (x2 - x1).abs();
    var dy = -(y2 - y1).abs();
    var sx = x1 < x2 ? 1 : -1;
    var sy = y1 < y2 ? 1 : -1;
    var err = dx + dy;

    var x = x1;
    var y = y1;

    while (true) {
      pixels.add(PixelPoint(x, y));

      if (x == x2 && y == y2) break;

      final e2 = 2 * err;

      if (e2 >= dy) {
        if (x == x2) break;
        err += dy;
        x += sx;
      }

      if (e2 <= dx) {
        if (y == y2) break;
        err += dx;
        y += sy;
      }
    }

    return pixels;
  }
}
