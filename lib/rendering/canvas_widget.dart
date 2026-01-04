import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/document/pixel_buffer.dart';
import 'canvas_render_object.dart';

/// Widget for rendering a pixel art canvas.
///
/// Uses [LeafRenderObjectWidget] for maximum performance, bypassing
/// the element tree for direct render object manipulation.
///
/// Takes a [PixelBuffer] and optional [transform] for pan/zoom,
/// and [dirtyRect] for partial updates.
class PixelCanvas extends LeafRenderObjectWidget {
  /// The pixel buffer to render.
  final PixelBuffer buffer;

  /// Transform matrix for pan and zoom.
  ///
  /// Defaults to identity (no transform).
  final Matrix4 transform;

  /// Dirty rectangle for partial updates.
  ///
  /// When non-null, only this region needs repainting.
  /// Null means the entire canvas should be repainted.
  final ui.Rect? dirtyRect;

  /// Whether to show a checkerboard background for transparency.
  final bool showCheckerboard;

  /// Size of the checkerboard squares (in canvas pixels).
  final int checkerboardSize;

  PixelCanvas({
    super.key,
    required this.buffer,
    Matrix4? transform,
    this.dirtyRect,
    this.showCheckerboard = true,
    this.checkerboardSize = 8,
  }) : transform = transform ?? Matrix4.identity();

  @override
  RenderPixelCanvas createRenderObject(BuildContext context) {
    return RenderPixelCanvas(
      buffer: buffer,
      transform: transform,
      dirtyRect: dirtyRect,
      showCheckerboard: showCheckerboard,
      checkerboardSize: checkerboardSize,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderPixelCanvas renderObject) {
    renderObject
      ..buffer = buffer
      ..transform = transform
      ..dirtyRect = dirtyRect
      ..showCheckerboard = showCheckerboard
      ..checkerboardSize = checkerboardSize;
  }
}
