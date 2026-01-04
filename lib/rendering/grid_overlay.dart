import 'dart:ui';

import 'package:flutter/rendering.dart';

import 'canvas_transform.dart';

/// Configuration for the pixel grid overlay.
class GridOverlayConfig {
  /// Whether the grid is visible.
  final bool visible;

  /// Minimum zoom level at which grid is shown.
  final double minZoomForGrid;

  /// Color of the grid lines.
  final Color gridColor;

  /// Width of grid lines in screen pixels.
  final double lineWidth;

  const GridOverlayConfig({
    this.visible = true,
    this.minZoomForGrid = 4.0,
    this.gridColor = const Color(0x40000000),
    this.lineWidth = 1.0,
  });

  GridOverlayConfig copyWith({
    bool? visible,
    double? minZoomForGrid,
    Color? gridColor,
    double? lineWidth,
  }) {
    return GridOverlayConfig(
      visible: visible ?? this.visible,
      minZoomForGrid: minZoomForGrid ?? this.minZoomForGrid,
      gridColor: gridColor ?? this.gridColor,
      lineWidth: lineWidth ?? this.lineWidth,
    );
  }

  /// Returns config with grid hidden.
  GridOverlayConfig hide() => copyWith(visible: false);

  /// Returns config with grid shown.
  GridOverlayConfig show() => copyWith(visible: true);

  /// Returns config with toggled visibility.
  GridOverlayConfig toggle() => copyWith(visible: !visible);
}

/// Renders a pixel grid overlay on the canvas.
///
/// The grid is only shown when zoomed in past [GridOverlayConfig.minZoomForGrid]
/// to avoid visual clutter at lower zoom levels. Only the visible portion of
/// the grid is rendered for efficiency.
class GridOverlay {
  /// Current configuration.
  GridOverlayConfig config;

  /// Cached paint for grid lines.
  Paint? _paint;

  GridOverlay({this.config = const GridOverlayConfig()});

  /// Whether the grid should be rendered at the current zoom level.
  bool shouldRender(double zoom) {
    return config.visible && zoom >= config.minZoomForGrid;
  }

  /// Renders the grid overlay.
  ///
  /// [canvas] - The canvas to paint on.
  /// [transform] - The current canvas transform for zoom/pan state.
  void render(Canvas canvas, CanvasTransform transform) {
    if (!shouldRender(transform.zoom)) return;

    final paint = _getPaint();
    final zoom = transform.zoom;
    final pan = transform.pan;
    final viewportSize = transform.viewportSize;
    final canvasSize = transform.canvasSize;

    // Calculate visible canvas region in canvas coordinates
    final visibleLeft = (-pan.dx / zoom).clamp(0.0, canvasSize.width);
    final visibleTop = (-pan.dy / zoom).clamp(0.0, canvasSize.height);
    final visibleRight =
        ((-pan.dx + viewportSize.width) / zoom).clamp(0.0, canvasSize.width);
    final visibleBottom =
        ((-pan.dy + viewportSize.height) / zoom).clamp(0.0, canvasSize.height);

    // Calculate grid bounds (pixel boundaries)
    final startX = visibleLeft.floor();
    final endX = visibleRight.ceil();
    final startY = visibleTop.floor();
    final endY = visibleBottom.ceil();

    // Draw vertical lines
    for (var x = startX; x <= endX; x++) {
      final screenX = x * zoom + pan.dx;
      canvas.drawLine(
        Offset(screenX, startY * zoom + pan.dy),
        Offset(screenX, endY * zoom + pan.dy),
        paint,
      );
    }

    // Draw horizontal lines
    for (var y = startY; y <= endY; y++) {
      final screenY = y * zoom + pan.dy;
      canvas.drawLine(
        Offset(startX * zoom + pan.dx, screenY),
        Offset(endX * zoom + pan.dx, screenY),
        paint,
      );
    }
  }

  /// Gets or creates the paint for grid lines.
  Paint _getPaint() {
    if (_paint == null ||
        _paint!.color != config.gridColor ||
        _paint!.strokeWidth != config.lineWidth) {
      _paint = Paint()
        ..color = config.gridColor
        ..strokeWidth = config.lineWidth
        ..style = PaintingStyle.stroke;
    }
    return _paint!;
  }

  /// Updates the configuration.
  void setConfig(GridOverlayConfig newConfig) {
    config = newConfig;
  }

  /// Toggles grid visibility.
  void toggle() {
    config = config.toggle();
  }

  /// Sets the grid color.
  void setColor(Color color) {
    config = config.copyWith(gridColor: color);
  }

  /// Sets the minimum zoom for grid display.
  void setMinZoom(double zoom) {
    config = config.copyWith(minZoomForGrid: zoom);
  }
}
