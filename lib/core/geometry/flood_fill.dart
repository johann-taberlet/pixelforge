import '../document/pixel_buffer.dart';
import 'point.dart';

/// Scanline-based flood fill algorithm.
///
/// Efficiently fills connected regions of the same color using a scanline
/// approach with a span stack.
class FloodFill {
  final PixelBuffer _buffer;
  final int _targetColor;
  final int _fillColor;
  final int _tolerance;

  FloodFill._({
    required PixelBuffer buffer,
    required int targetColor,
    required int fillColor,
    int tolerance = 0,
  })  : _buffer = buffer,
        _targetColor = targetColor,
        _fillColor = fillColor,
        _tolerance = tolerance;

  /// Performs flood fill starting from the given point.
  ///
  /// [buffer] is the pixel buffer to fill.
  /// [start] is the starting point for the fill.
  /// [fillColor] is the color to fill with.
  /// [tolerance] is the color matching tolerance (0-255).
  ///
  /// Returns the list of points that were filled.
  static List<Point> fill({
    required PixelBuffer buffer,
    required Point start,
    required int fillColor,
    int tolerance = 0,
  }) {
    if (!buffer.contains(start.x, start.y)) return [];

    final targetColor = buffer.getPixel(start.x, start.y);
    if (targetColor == fillColor) return [];

    final filler = FloodFill._(
      buffer: buffer,
      targetColor: targetColor,
      fillColor: fillColor,
      tolerance: tolerance,
    );

    return filler._scanlineFill(start);
  }

  /// Scanline flood fill implementation.
  List<Point> _scanlineFill(Point start) {
    final filled = <Point>[];
    final visited = <int>{};
    final stack = <_Span>[];

    // Find the initial span
    final (left, right) = _findSpan(start.y, start.x);
    stack.add(_Span(start.y, left, right));
    _markVisited(visited, start.y, left, right);

    while (stack.isNotEmpty) {
      final span = stack.removeLast();

      // Fill this span
      for (var x = span.left; x <= span.right; x++) {
        _buffer.setPixel(x, span.y, _fillColor);
        filled.add(Point(x, span.y));
      }

      // Check scanlines above and below
      _checkScanline(stack, visited, span.y - 1, span.left, span.right);
      _checkScanline(stack, visited, span.y + 1, span.left, span.right);
    }

    return filled;
  }

  /// Finds the leftmost and rightmost extent of a span.
  (int, int) _findSpan(int y, int x) {
    var left = x;
    var right = x;

    // Extend left
    while (left > 0 && _matchesTarget(left - 1, y)) {
      left--;
    }

    // Extend right
    while (right < _buffer.width - 1 && _matchesTarget(right + 1, y)) {
      right++;
    }

    return (left, right);
  }

  /// Checks a scanline for new spans to fill.
  void _checkScanline(
    List<_Span> stack,
    Set<int> visited,
    int y,
    int left,
    int right,
  ) {
    if (y < 0 || y >= _buffer.height) return;

    var x = left;
    while (x <= right) {
      // Skip non-matching pixels
      while (x <= right && !_matchesTarget(x, y)) {
        x++;
      }
      if (x > right) break;

      // Found a matching pixel, find the span
      final spanStart = x;
      while (x <= right && _matchesTarget(x, y)) {
        x++;
      }

      // Extend the span beyond the parent's bounds
      final (extendedLeft, extendedRight) = _findSpan(y, spanStart);

      // Check if we've already visited this span
      if (!_isVisited(visited, y, extendedLeft, extendedRight)) {
        stack.add(_Span(y, extendedLeft, extendedRight));
        _markVisited(visited, y, extendedLeft, extendedRight);
      }
    }
  }

  /// Checks if a pixel matches the target color within tolerance.
  bool _matchesTarget(int x, int y) {
    final color = _buffer.getPixel(x, y);
    if (_tolerance == 0) return color == _targetColor;
    return _colorDifference(color, _targetColor) <= _tolerance;
  }

  /// Calculates the maximum component difference between two colors.
  int _colorDifference(int a, int b) {
    final aA = (a >> 24) & 0xFF;
    final aB = (a >> 16) & 0xFF;
    final aG = (a >> 8) & 0xFF;
    final aR = a & 0xFF;

    final bA = (b >> 24) & 0xFF;
    final bB = (b >> 16) & 0xFF;
    final bG = (b >> 8) & 0xFF;
    final bR = b & 0xFF;

    var diff = (aA - bA).abs();
    if ((aR - bR).abs() > diff) diff = (aR - bR).abs();
    if ((aG - bG).abs() > diff) diff = (aG - bG).abs();
    if ((aB - bB).abs() > diff) diff = (aB - bB).abs();

    return diff;
  }

  /// Marks a span as visited using a hash-based approach.
  void _markVisited(Set<int> visited, int y, int left, int right) {
    // Use a hash to track visited spans
    visited.add(y * 100000 + left);
  }

  /// Checks if a span has been visited.
  bool _isVisited(Set<int> visited, int y, int left, int right) {
    return visited.contains(y * 100000 + left);
  }
}

/// Internal representation of a horizontal span.
class _Span {
  final int y;
  final int left;
  final int right;

  _Span(this.y, this.left, this.right);
}
