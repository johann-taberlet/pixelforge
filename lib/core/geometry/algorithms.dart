import 'point.dart';

/// Drawing algorithms for pixel art.
///
/// All algorithms use integer coordinates and produce pixel-perfect results.
abstract final class DrawingAlgorithms {
  /// Generates points along a line using Bresenham's algorithm.
  ///
  /// Returns all pixel coordinates that form a line from [start] to [end].
  /// The algorithm produces smooth, pixel-perfect lines without gaps.
  static Iterable<Point> bresenhamLine(Point start, Point end) sync* {
    var x0 = start.x;
    var y0 = start.y;
    final x1 = end.x;
    final y1 = end.y;

    final dx = (x1 - x0).abs();
    final dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;

    while (true) {
      yield Point(x0, y0);

      if (x0 == x1 && y0 == y1) break;

      final e2 = 2 * err;
      if (e2 >= dy) {
        if (x0 == x1) break;
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        if (y0 == y1) break;
        err += dx;
        y0 += sy;
      }
    }
  }

  /// Generates points along a circle outline using midpoint circle algorithm.
  ///
  /// Returns all pixel coordinates that form a circle centered at [center]
  /// with the given [radius].
  static Iterable<Point> circle(Point center, int radius) sync* {
    if (radius <= 0) {
      yield center;
      return;
    }

    var x = radius;
    var y = 0;
    var err = 0;

    while (x >= y) {
      yield Point(center.x + x, center.y + y);
      yield Point(center.x + y, center.y + x);
      yield Point(center.x - y, center.y + x);
      yield Point(center.x - x, center.y + y);
      yield Point(center.x - x, center.y - y);
      yield Point(center.x - y, center.y - x);
      yield Point(center.x + y, center.y - x);
      yield Point(center.x + x, center.y - y);

      y++;
      if (err <= 0) {
        err += 2 * y + 1;
      }
      if (err > 0) {
        x--;
        err -= 2 * x + 1;
      }
    }
  }

  /// Generates points inside a filled circle.
  ///
  /// Returns all pixel coordinates inside a circle centered at [center]
  /// with the given [radius], using scanline fill.
  static Iterable<Point> filledCircle(Point center, int radius) sync* {
    if (radius <= 0) {
      yield center;
      return;
    }

    var x = radius;
    var y = 0;
    var err = 0;

    while (x >= y) {
      // Draw horizontal lines for each octant pair
      for (var i = center.x - x; i <= center.x + x; i++) {
        yield Point(i, center.y + y);
        yield Point(i, center.y - y);
      }
      for (var i = center.x - y; i <= center.x + y; i++) {
        yield Point(i, center.y + x);
        yield Point(i, center.y - x);
      }

      y++;
      if (err <= 0) {
        err += 2 * y + 1;
      }
      if (err > 0) {
        x--;
        err -= 2 * x + 1;
      }
    }
  }

  /// Generates points along an ellipse outline.
  ///
  /// Returns all pixel coordinates that form an ellipse centered at [center]
  /// with the given [radiusX] and [radiusY].
  static Iterable<Point> ellipse(
    Point center,
    int radiusX,
    int radiusY,
  ) sync* {
    if (radiusX <= 0 && radiusY <= 0) {
      yield center;
      return;
    }
    if (radiusX <= 0) {
      for (var y = -radiusY; y <= radiusY; y++) {
        yield Point(center.x, center.y + y);
      }
      return;
    }
    if (radiusY <= 0) {
      for (var x = -radiusX; x <= radiusX; x++) {
        yield Point(center.x + x, center.y);
      }
      return;
    }

    final a2 = radiusX * radiusX;
    final b2 = radiusY * radiusY;
    final fa2 = 4 * a2;
    final fb2 = 4 * b2;

    int x, y, sigma;

    // First half
    x = 0;
    y = radiusY;
    sigma = 2 * b2 + a2 * (1 - 2 * radiusY);
    while (b2 * x <= a2 * y) {
      yield Point(center.x + x, center.y + y);
      yield Point(center.x - x, center.y + y);
      yield Point(center.x + x, center.y - y);
      yield Point(center.x - x, center.y - y);
      if (sigma >= 0) {
        sigma += fa2 * (1 - y);
        y--;
      }
      sigma += b2 * (4 * x + 6);
      x++;
    }

    // Second half
    x = radiusX;
    y = 0;
    sigma = 2 * a2 + b2 * (1 - 2 * radiusX);
    while (a2 * y <= b2 * x) {
      yield Point(center.x + x, center.y + y);
      yield Point(center.x - x, center.y + y);
      yield Point(center.x + x, center.y - y);
      yield Point(center.x - x, center.y - y);
      if (sigma >= 0) {
        sigma += fb2 * (1 - x);
        x--;
      }
      sigma += a2 * (4 * y + 6);
      y++;
    }
  }

  /// Generates points along a rectangle outline.
  static Iterable<Point> rectangle(int x, int y, int width, int height) sync* {
    if (width <= 0 || height <= 0) return;

    // Top edge
    for (var i = x; i < x + width; i++) {
      yield Point(i, y);
    }
    // Right edge
    for (var j = y + 1; j < y + height; j++) {
      yield Point(x + width - 1, j);
    }
    // Bottom edge
    if (height > 1) {
      for (var i = x + width - 2; i >= x; i--) {
        yield Point(i, y + height - 1);
      }
    }
    // Left edge
    if (width > 1) {
      for (var j = y + height - 2; j > y; j--) {
        yield Point(x, j);
      }
    }
  }

  /// Generates points inside a filled rectangle.
  static Iterable<Point> filledRectangle(
    int x,
    int y,
    int width,
    int height,
  ) sync* {
    for (var j = y; j < y + height; j++) {
      for (var i = x; i < x + width; i++) {
        yield Point(i, j);
      }
    }
  }
}
