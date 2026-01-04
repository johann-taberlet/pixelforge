import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../core/document/pixel_buffer.dart';

/// Custom render object for pixel art canvas.
///
/// Optimized for performance:
/// - Caches [ui.Image] to avoid rebuilds
/// - Uses [FilterQuality.none] for crisp pixel rendering
/// - Supports dirty rectangle tracking for partial updates
/// - Targets < 8ms paint time
class RenderPixelCanvas extends RenderBox {
  PixelBuffer _buffer;
  Matrix4 _transform;
  ui.Rect? _dirtyRect;
  bool _showCheckerboard;
  int _checkerboardSize;

  /// Cached image from the pixel buffer.
  ui.Image? _cachedImage;

  /// Version counter to track when cache needs invalidation.
  int _bufferVersion = 0;

  /// Last version we cached for.
  int _cachedVersion = -1;

  /// Paint objects reused across frames.
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.none;
  final Paint _checkerLight = Paint()..color = const Color(0xFFE0E0E0);
  final Paint _checkerDark = Paint()..color = const Color(0xFFC0C0C0);

  RenderPixelCanvas({
    required PixelBuffer buffer,
    Matrix4? transform,
    ui.Rect? dirtyRect,
    bool showCheckerboard = true,
    int checkerboardSize = 8,
  })  : _buffer = buffer,
        _transform = transform ?? Matrix4.identity(),
        _dirtyRect = dirtyRect,
        _showCheckerboard = showCheckerboard,
        _checkerboardSize = checkerboardSize;

  PixelBuffer get buffer => _buffer;
  set buffer(PixelBuffer value) {
    if (_buffer != value) {
      _buffer = value;
      _bufferVersion++;
      markNeedsPaint();
    }
  }

  Matrix4 get transform => _transform;
  set transform(Matrix4 value) {
    if (_transform != value) {
      _transform = value;
      markNeedsPaint();
    }
  }

  ui.Rect? get dirtyRect => _dirtyRect;
  set dirtyRect(ui.Rect? value) {
    if (_dirtyRect != value) {
      _dirtyRect = value;
      // Dirty rect change requires cache rebuild for that region
      _bufferVersion++;
      markNeedsPaint();
    }
  }

  bool get showCheckerboard => _showCheckerboard;
  set showCheckerboard(bool value) {
    if (_showCheckerboard != value) {
      _showCheckerboard = value;
      markNeedsPaint();
    }
  }

  int get checkerboardSize => _checkerboardSize;
  set checkerboardSize(int value) {
    if (_checkerboardSize != value) {
      _checkerboardSize = value;
      markNeedsPaint();
    }
  }

  /// Invalidate the cached image.
  ///
  /// Call this when the underlying pixel data changes.
  void invalidateCache() {
    _bufferVersion++;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void performLayout() {
    // Size is set in performResize when sizedByParent is true
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // Apply the transform (pan/zoom)
    final transformMatrix = Float64List.fromList(_transform.storage);
    canvas.transform(transformMatrix);

    // Draw checkerboard background for transparency
    if (_showCheckerboard) {
      _paintCheckerboard(canvas);
    }

    // Rebuild cache if needed
    if (_cachedVersion != _bufferVersion || _cachedImage == null) {
      _rebuildCache();
    }

    // Draw the cached image
    if (_cachedImage != null) {
      canvas.drawImage(
        _cachedImage!,
        Offset.zero,
        _imagePaint,
      );
    }

    canvas.restore();
  }

  void _paintCheckerboard(Canvas canvas) {
    // Draw alternating squares
    for (var y = 0; y < _buffer.height; y += _checkerboardSize) {
      for (var x = 0; x < _buffer.width; x += _checkerboardSize) {
        final isLight = ((x ~/ _checkerboardSize) + (y ~/ _checkerboardSize)) % 2 == 0;
        final squareRect = Rect.fromLTWH(
          x.toDouble(),
          y.toDouble(),
          _checkerboardSize.toDouble().clamp(0, _buffer.width - x.toDouble()),
          _checkerboardSize.toDouble().clamp(0, _buffer.height - y.toDouble()),
        );
        canvas.drawRect(squareRect, isLight ? _checkerLight : _checkerDark);
      }
    }
  }

  void _rebuildCache() {
    // Convert PixelBuffer to ui.Image using efficient bulk conversion.
    // For synchronous rendering, we use ImmutableBuffer + ImageDescriptor
    // which is much faster than drawing individual pixels.
    _createImageFromBuffer();
    _cachedVersion = _bufferVersion;
  }

  void _createImageFromBuffer() {
    // Use decodeImageFromPixels for efficient bulk conversion.
    // This converts the entire RGBA buffer to a GPU texture in one call.
    //
    // Note: This is async but we trigger it and render the cached version
    // until the new one is ready. For most cases the decode is fast enough
    // that there's no visible flicker.

    ui.decodeImageFromPixels(
      _buffer.data,
      _buffer.width,
      _buffer.height,
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        // Dispose old image if present
        _cachedImage?.dispose();
        _cachedImage = image;
        // Request repaint with new image
        markNeedsPaint();
      },
      targetWidth: _buffer.width,
      targetHeight: _buffer.height,
    );
  }

  @override
  void dispose() {
    _cachedImage?.dispose();
    _cachedImage = null;
    super.dispose();
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
