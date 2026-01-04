import '../core/document/pixel_buffer.dart';
import '../core/geometry/flood_fill.dart';
import '../core/geometry/point.dart';
import 'tool.dart';

/// Fill bucket tool for flood filling connected regions.
///
/// Supports:
/// - Scanline flood fill algorithm for efficient filling
/// - Color tolerance for filling similar colors
/// - Contiguous mode (fill connected pixels) vs global mode (fill all matching)
class FillTool extends Tool with ToleranceTool, FillModeTool {
  ToolState _state = ToolState.idle;

  @override
  int tolerance = 0;

  @override
  bool contiguous = true;

  @override
  String get id => 'fill';

  @override
  String get name => 'Fill';

  @override
  ToolState get state => _state;

  @override
  void onStart(Point position, ToolContext context) {
    _state = ToolState.active;

    // Perform the fill immediately on click
    _performFill(position, context);

    _state = ToolState.idle;
  }

  @override
  void onUpdate(Point position, ToolContext context) {
    // Fill tool doesn't track movement
  }

  @override
  void onEnd(Point position, ToolContext context) {
    _state = ToolState.idle;
  }

  @override
  void onCancel(ToolContext context) {
    _state = ToolState.idle;
  }

  /// Performs the fill operation.
  void _performFill(Point position, ToolContext context) {
    final x = position.x;
    final y = position.y;

    // Bounds check
    if (x < 0 || x >= context.canvasWidth ||
        y < 0 || y >= context.canvasHeight) {
      return;
    }

    final targetColor = context.getPixel(x, y);
    final fillColor = context.foregroundColor;

    // Don't fill if colors are the same
    if (_colorsMatch(targetColor, fillColor, 0)) {
      return;
    }

    if (contiguous) {
      _fillContiguous(position, targetColor, fillColor, context);
    } else {
      _fillGlobal(targetColor, fillColor, context);
    }

    context.commit('Fill');
  }

  /// Fills contiguous pixels using scanline flood fill.
  void _fillContiguous(
    Point start,
    int targetColor,
    int fillColor,
    ToolContext context,
  ) {
    // Create a temporary buffer to work with
    final buffer = PixelBuffer(context.canvasWidth, context.canvasHeight);

    // Copy current canvas state to buffer
    for (var y = 0; y < context.canvasHeight; y++) {
      for (var x = 0; x < context.canvasWidth; x++) {
        buffer.setPixelRaw(x, y, context.getPixel(x, y));
      }
    }

    // Perform flood fill
    final filled = FloodFill.fill(
      buffer: buffer,
      start: start,
      fillColor: fillColor,
      tolerance: tolerance,
    );

    // Apply filled pixels back to context
    var minX = context.canvasWidth;
    var minY = context.canvasHeight;
    var maxX = 0;
    var maxY = 0;

    for (final point in filled) {
      context.setPixel(point.x, point.y, fillColor);
      minX = minX < point.x ? minX : point.x;
      minY = minY < point.y ? minY : point.y;
      maxX = maxX > point.x ? maxX : point.x;
      maxY = maxY > point.y ? maxY : point.y;
    }

    // Mark dirty region
    if (filled.isNotEmpty) {
      context.markDirty(minX, minY, maxX - minX + 1, maxY - minY + 1);
    }
  }

  /// Fills all matching pixels globally (non-contiguous).
  void _fillGlobal(
    int targetColor,
    int fillColor,
    ToolContext context,
  ) {
    var minX = context.canvasWidth;
    var minY = context.canvasHeight;
    var maxX = 0;
    var maxY = 0;
    var changed = false;

    for (var y = 0; y < context.canvasHeight; y++) {
      for (var x = 0; x < context.canvasWidth; x++) {
        final color = context.getPixel(x, y);
        if (_colorsMatch(color, targetColor, tolerance)) {
          context.setPixel(x, y, fillColor);
          minX = minX < x ? minX : x;
          minY = minY < y ? minY : y;
          maxX = maxX > x ? maxX : x;
          maxY = maxY > y ? maxY : y;
          changed = true;
        }
      }
    }

    if (changed) {
      context.markDirty(minX, minY, maxX - minX + 1, maxY - minY + 1);
    }
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
