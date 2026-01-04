import 'dart:math' as math;

/// An immutable 2D integer point for pixel coordinates.
class Point {
  /// The x coordinate.
  final int x;

  /// The y coordinate.
  final int y;

  /// Creates a point at the given coordinates.
  const Point(this.x, this.y);

  /// The origin point (0, 0).
  static const zero = Point(0, 0);

  /// Returns a new point offset by the given amounts.
  Point translate(int dx, int dy) => Point(x + dx, y + dy);

  /// Returns the point offset by another point.
  Point operator +(Point other) => Point(x + other.x, y + other.y);

  /// Returns the difference between two points.
  Point operator -(Point other) => Point(x - other.x, y - other.y);

  /// Returns the point scaled by a factor.
  Point operator *(int factor) => Point(x * factor, y * factor);

  /// Returns the negated point.
  Point operator -() => Point(-x, -y);

  /// Manhattan distance to another point.
  int manhattanDistanceTo(Point other) =>
      (x - other.x).abs() + (y - other.y).abs();

  /// Squared Euclidean distance to another point.
  ///
  /// Use this instead of [distanceTo] when you only need to compare distances.
  int distanceSquaredTo(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return dx * dx + dy * dy;
  }

  /// Euclidean distance to another point.
  double distanceTo(Point other) => math.sqrt(distanceSquaredTo(other));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Point && other.x == x && other.y == y);

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}
