import 'dart:math' as math;

import '../input/input_controller.dart';
import 'tool.dart';

/// A pixel coordinate.
typedef PixelPoint = math.Point<int>;

/// Base class for shape tools (line, rectangle, ellipse).
///
/// Provides common behavior:
/// - Start/end point tracking
/// - Shift-constrain for aspect ratio locking
/// - Preview during drag
/// - Commit on release
abstract class ShapeTool extends Tool {
  /// Starting point of the shape.
  CanvasPoint? startPoint;

  /// Current end point of the shape (updated during drag).
  CanvasPoint? endPoint;

  /// Whether shift is held for constraint (square/circle/45-degree).
  bool isConstrained = false;

  /// Current drawing color (0xRRGGBBAA format).
  int color = 0x000000FF;

  /// Whether to fill the shape (for rectangle/ellipse).
  bool filled = false;

  /// Callback for drawing pixels to the canvas.
  void Function(List<PixelPoint> pixels, int color)? onDrawPixels;

  /// Callback for showing shape preview.
  void Function(List<PixelPoint> previewPixels)? onShowPreview;

  /// Callback for clearing preview.
  void Function()? onClearPreview;

  @override
  void onStart(CanvasInputEvent event) {
    super.onStart(event);
    startPoint = event.point;
    endPoint = event.point;
  }

  @override
  void onUpdate(CanvasInputEvent event) {
    endPoint = event.point;
    _showPreview();
  }

  @override
  void onEnd(CanvasInputEvent event) {
    endPoint = event.point;
    _commitShape();
    _clearState();
    super.onEnd(event);
  }

  @override
  void onCancel() {
    onClearPreview?.call();
    _clearState();
    super.onCancel();
  }

  void _showPreview() {
    if (startPoint == null || endPoint == null) return;

    final constrained = applyConstraint(
      startPoint!.pixelX,
      startPoint!.pixelY,
      endPoint!.pixelX,
      endPoint!.pixelY,
    );

    final pixels = computeShapePixels(
      startPoint!.pixelX,
      startPoint!.pixelY,
      constrained.x,
      constrained.y,
    );

    onShowPreview?.call(pixels);
  }

  void _commitShape() {
    if (startPoint == null || endPoint == null) return;

    final constrained = applyConstraint(
      startPoint!.pixelX,
      startPoint!.pixelY,
      endPoint!.pixelX,
      endPoint!.pixelY,
    );

    final pixels = computeShapePixels(
      startPoint!.pixelX,
      startPoint!.pixelY,
      constrained.x,
      constrained.y,
    );

    onDrawPixels?.call(pixels, color);
    onClearPreview?.call();
  }

  void _clearState() {
    startPoint = null;
    endPoint = null;
  }

  /// Apply constraint to end point if [isConstrained] is true.
  ///
  /// Override in subclasses for specific constraint behavior.
  /// Returns the (potentially modified) end point.
  PixelPoint applyConstraint(int startX, int startY, int endX, int endY) {
    if (!isConstrained) {
      return PixelPoint(endX, endY);
    }
    return doApplyConstraint(startX, startY, endX, endY);
  }

  /// Implement constraint logic.
  ///
  /// Override in subclasses. Called only when [isConstrained] is true.
  PixelPoint doApplyConstraint(int startX, int startY, int endX, int endY) {
    return PixelPoint(endX, endY);
  }

  /// Compute the pixels that make up the shape.
  ///
  /// Override in subclasses to implement specific shape algorithms.
  List<PixelPoint> computeShapePixels(int x1, int y1, int x2, int y2);
}

/// Base class for shapes with 1:1 aspect ratio constraint (square/circle).
abstract class AspectRatioShapeTool extends ShapeTool {
  @override
  PixelPoint doApplyConstraint(int startX, int startY, int endX, int endY) {
    final dx = endX - startX;
    final dy = endY - startY;
    final size = math.max(dx.abs(), dy.abs());

    return PixelPoint(
      startX + (dx.sign * size).toInt(),
      startY + (dy.sign * size).toInt(),
    );
  }
}

/// Base class for line shapes with 45-degree angle constraint.
abstract class AngleConstrainedShapeTool extends ShapeTool {
  @override
  PixelPoint doApplyConstraint(int startX, int startY, int endX, int endY) {
    final dx = endX - startX;
    final dy = endY - startY;

    // Calculate angle and snap to nearest 45 degrees
    final angle = math.atan2(dy.toDouble(), dx.toDouble());
    final snappedAngle = (angle / (math.pi / 4)).round() * (math.pi / 4);

    final length = math.sqrt((dx * dx + dy * dy).toDouble());

    return PixelPoint(
      startX + (length * math.cos(snappedAngle)).round(),
      startY + (length * math.sin(snappedAngle)).round(),
    );
  }
}
