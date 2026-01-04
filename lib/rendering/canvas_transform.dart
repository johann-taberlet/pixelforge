import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

/// Manages the transformation matrix for canvas zoom and pan.
///
/// Provides smooth interpolation between zoom levels and handles
/// coordinate conversion between screen and canvas space.
class CanvasTransform extends ChangeNotifier {
  /// Minimum zoom level (1x = 1 canvas pixel = 1 screen pixel).
  static const double minZoom = 1.0;

  /// Maximum zoom level (64x = 1 canvas pixel = 64 screen pixels).
  static const double maxZoom = 64.0;

  /// Current zoom level.
  double _zoom = 1.0;

  /// Current pan offset in canvas coordinates.
  Offset _pan = Offset.zero;

  /// Canvas size in pixels.
  Size _canvasSize = Size.zero;

  /// Viewport size in screen pixels.
  Size _viewportSize = Size.zero;

  /// Cached transformation matrix.
  Matrix4? _cachedMatrix;

  /// Cached inverse transformation matrix.
  Matrix4? _cachedInverse;

  /// Current zoom level (1.0 to 64.0).
  double get zoom => _zoom;

  /// Current pan offset in canvas coordinates.
  Offset get pan => _pan;

  /// Canvas size in pixels.
  Size get canvasSize => _canvasSize;

  /// Viewport size in screen pixels.
  Size get viewportSize => _viewportSize;

  /// The transformation matrix for rendering.
  ///
  /// Transforms from canvas coordinates to screen coordinates.
  Matrix4 get matrix {
    _cachedMatrix ??= _computeMatrix();
    return _cachedMatrix!;
  }

  /// The inverse transformation matrix.
  ///
  /// Transforms from screen coordinates to canvas coordinates.
  Matrix4 get inverseMatrix {
    _cachedInverse ??= Matrix4.tryInvert(matrix) ?? Matrix4.identity();
    return _cachedInverse!;
  }

  /// Set the canvas size.
  void setCanvasSize(Size size) {
    if (_canvasSize == size) return;
    _canvasSize = size;
    _clampPan();
    _invalidateCache();
    notifyListeners();
  }

  /// Set the viewport size.
  void setViewportSize(Size size) {
    if (_viewportSize == size) return;
    _viewportSize = size;
    _clampPan();
    _invalidateCache();
    notifyListeners();
  }

  /// Set the zoom level, clamped to valid range.
  ///
  /// [focalPoint] is the screen coordinate that should remain stationary
  /// during the zoom operation (typically the pinch center).
  void setZoom(double newZoom, {Offset? focalPoint}) {
    newZoom = newZoom.clamp(minZoom, maxZoom);
    if (_zoom == newZoom) return;

    if (focalPoint != null) {
      // Convert focal point to canvas coordinates before zoom
      final canvasPoint = screenToCanvas(focalPoint);

      _zoom = newZoom;
      _invalidateCache();

      // Adjust pan so the focal point stays at the same screen position
      final newScreenPoint = canvasToScreen(canvasPoint);
      final delta = focalPoint - newScreenPoint;
      _pan = Offset(
        _pan.dx - delta.dx / _zoom,
        _pan.dy - delta.dy / _zoom,
      );
    } else {
      _zoom = newZoom;
    }

    _clampPan();
    _invalidateCache();
    notifyListeners();
  }

  /// Multiply the current zoom by a factor.
  ///
  /// [focalPoint] is the screen coordinate that should remain stationary.
  void zoomBy(double factor, {Offset? focalPoint}) {
    setZoom(_zoom * factor, focalPoint: focalPoint);
  }

  /// Set the pan offset in canvas coordinates.
  void setPan(Offset newPan) {
    _pan = newPan;
    _clampPan();
    _invalidateCache();
    notifyListeners();
  }

  /// Add a delta to the current pan in screen coordinates.
  void panBy(Offset screenDelta) {
    _pan = Offset(
      _pan.dx + screenDelta.dx / _zoom,
      _pan.dy + screenDelta.dy / _zoom,
    );
    _clampPan();
    _invalidateCache();
    notifyListeners();
  }

  /// Convert a screen coordinate to canvas coordinate.
  Offset screenToCanvas(Offset screenPoint) {
    final vector = Vector4(screenPoint.dx, screenPoint.dy, 0.0, 1.0);
    inverseMatrix.transform(vector);
    return Offset(vector.x, vector.y);
  }

  /// Convert a canvas coordinate to screen coordinate.
  Offset canvasToScreen(Offset canvasPoint) {
    final vector = Vector4(canvasPoint.dx, canvasPoint.dy, 0.0, 1.0);
    matrix.transform(vector);
    return Offset(vector.x, vector.y);
  }

  /// Get the visible canvas region in canvas coordinates.
  Rect get visibleCanvasRect {
    final topLeft = screenToCanvas(Offset.zero);
    final bottomRight = screenToCanvas(
      Offset(_viewportSize.width, _viewportSize.height),
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  /// Check if a canvas point is currently visible.
  bool isPointVisible(Offset canvasPoint) {
    return visibleCanvasRect.contains(canvasPoint);
  }

  /// Center the view on a specific canvas coordinate.
  void centerOn(Offset canvasPoint) {
    _pan = Offset(
      canvasPoint.dx - (_viewportSize.width / 2) / _zoom,
      canvasPoint.dy - (_viewportSize.height / 2) / _zoom,
    );
    _clampPan();
    _invalidateCache();
    notifyListeners();
  }

  /// Fit the entire canvas in the viewport.
  void fitToView() {
    if (_canvasSize.isEmpty || _viewportSize.isEmpty) return;

    final scaleX = _viewportSize.width / _canvasSize.width;
    final scaleY = _viewportSize.height / _canvasSize.height;
    _zoom = scaleX.clamp(minZoom, maxZoom);
    if (scaleY < scaleX) {
      _zoom = scaleY.clamp(minZoom, maxZoom);
    }

    // Center the canvas
    _pan = Offset(
      -(_viewportSize.width / _zoom - _canvasSize.width) / 2,
      -(_viewportSize.height / _zoom - _canvasSize.height) / 2,
    );

    _clampPan();
    _invalidateCache();
    notifyListeners();
  }

  /// Reset to default zoom (1x) and center the canvas.
  void reset() {
    _zoom = 1.0;
    _pan = Offset.zero;
    _invalidateCache();
    notifyListeners();
  }

  Matrix4 _computeMatrix() {
    // Order: translate (pan), then scale (zoom)
    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, _zoom);
    matrix.setEntry(1, 1, _zoom);
    matrix.setEntry(0, 3, -_pan.dx * _zoom);
    matrix.setEntry(1, 3, -_pan.dy * _zoom);
    return matrix;
  }

  void _invalidateCache() {
    _cachedMatrix = null;
    _cachedInverse = null;
  }

  void _clampPan() {
    if (_canvasSize.isEmpty || _viewportSize.isEmpty) return;

    // Calculate the visible area in canvas units
    final visibleWidth = _viewportSize.width / _zoom;
    final visibleHeight = _viewportSize.height / _zoom;

    // Allow some overdraw but keep at least half the canvas visible
    final minX = -visibleWidth / 2;
    final maxX = _canvasSize.width - visibleWidth / 2;
    final minY = -visibleHeight / 2;
    final maxY = _canvasSize.height - visibleHeight / 2;

    _pan = Offset(
      _pan.dx.clamp(minX, maxX),
      _pan.dy.clamp(minY, maxY),
    );
  }
}

/// Animated version of [CanvasTransform] with smooth interpolation.
class AnimatedCanvasTransform extends CanvasTransform {
  /// Duration for zoom animations.
  Duration zoomDuration = const Duration(milliseconds: 150);

  /// Duration for pan animations.
  Duration panDuration = const Duration(milliseconds: 100);

  // Animation state could be added here for smooth transitions
  // using AnimationController when needed
}
