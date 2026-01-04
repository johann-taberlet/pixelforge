import 'dart:math' as math;

import 'point.dart';

/// An immutable integer rectangle for pixel regions.
class Rect {
  /// Left edge x coordinate.
  final int x;

  /// Top edge y coordinate.
  final int y;

  /// Width of the rectangle.
  final int width;

  /// Height of the rectangle.
  final int height;

  /// Creates a rectangle from position and size.
  const Rect(this.x, this.y, this.width, this.height);

  /// Creates a rectangle from two corner points.
  factory Rect.fromPoints(Point a, Point b) {
    final x1 = math.min(a.x, b.x);
    final y1 = math.min(a.y, b.y);
    final x2 = math.max(a.x, b.x);
    final y2 = math.max(a.y, b.y);
    return Rect(x1, y1, x2 - x1, y2 - y1);
  }

  /// Creates a rectangle from left, top, right, bottom edges.
  factory Rect.fromLTRB(int left, int top, int right, int bottom) {
    return Rect(left, top, right - left, bottom - top);
  }

  /// An empty rectangle at the origin.
  static const empty = Rect(0, 0, 0, 0);

  /// Right edge x coordinate (exclusive).
  int get right => x + width;

  /// Bottom edge y coordinate (exclusive).
  int get bottom => y + height;

  /// Left edge (alias for x).
  int get left => x;

  /// Top edge (alias for y).
  int get top => y;

  /// Top-left corner.
  Point get topLeft => Point(x, y);

  /// Top-right corner.
  Point get topRight => Point(right, y);

  /// Bottom-left corner.
  Point get bottomLeft => Point(x, bottom);

  /// Bottom-right corner.
  Point get bottomRight => Point(right, bottom);

  /// Center point (rounded down).
  Point get center => Point(x + width ~/ 2, y + height ~/ 2);

  /// Area of the rectangle.
  int get area => width * height;

  /// Whether the rectangle has zero area.
  bool get isEmpty => width <= 0 || height <= 0;

  /// Whether the rectangle has positive area.
  bool get isNotEmpty => !isEmpty;

  /// Returns true if the point is inside the rectangle.
  bool contains(Point p) =>
      p.x >= x && p.x < right && p.y >= y && p.y < bottom;

  /// Returns true if the point coordinates are inside the rectangle.
  bool containsXY(int px, int py) =>
      px >= x && px < right && py >= y && py < bottom;

  /// Returns true if this rectangle intersects another.
  bool intersects(Rect other) =>
      x < other.right &&
      right > other.x &&
      y < other.bottom &&
      bottom > other.y;

  /// Returns the intersection of two rectangles, or empty if they don't intersect.
  Rect intersection(Rect other) {
    final x1 = math.max(x, other.x);
    final y1 = math.max(y, other.y);
    final x2 = math.min(right, other.right);
    final y2 = math.min(bottom, other.bottom);
    if (x2 <= x1 || y2 <= y1) return empty;
    return Rect(x1, y1, x2 - x1, y2 - y1);
  }

  /// Returns the smallest rectangle containing both rectangles.
  Rect union(Rect other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    final x1 = math.min(x, other.x);
    final y1 = math.min(y, other.y);
    final x2 = math.max(right, other.right);
    final y2 = math.max(bottom, other.bottom);
    return Rect(x1, y1, x2 - x1, y2 - y1);
  }

  /// Returns a new rectangle translated by the given offset.
  Rect translate(int dx, int dy) => Rect(x + dx, y + dy, width, height);

  /// Returns a new rectangle expanded by the given amount on all sides.
  Rect inflate(int delta) =>
      Rect(x - delta, y - delta, width + delta * 2, height + delta * 2);

  /// Returns a new rectangle contracted by the given amount on all sides.
  Rect deflate(int delta) => inflate(-delta);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rect &&
          other.x == x &&
          other.y == y &&
          other.width == width &&
          other.height == height);

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'Rect($x, $y, $width, $height)';
}
