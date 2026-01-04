import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/document/pixel_buffer.dart';
import '../platform/gpu_renderer.dart';
import 'pencil_tool.dart';

/// Bridges tool actions to pixel buffer updates.
///
/// Connects tool output (PixelDraw lists) to:
/// - PixelBuffer for immediate CPU-side updates
/// - GpuRenderer for GPU-accelerated rendering (when available)
/// - Repaint notifications for UI updates
class ToolRenderer extends ChangeNotifier {
  /// The current pixel buffer being drawn to.
  PixelBuffer? _buffer;

  /// The GPU renderer for accelerated updates (optional).
  GpuRenderer? _gpuRenderer;

  /// The layer ID for GPU operations.
  int? _layerId;

  /// Whether to batch updates for performance.
  bool batchUpdates = true;

  /// Pending pixel updates for batching.
  final List<PixelUpdate> _pendingUpdates = [];

  /// Set the target pixel buffer.
  void setBuffer(PixelBuffer? buffer) {
    if (_buffer == buffer) return;
    _buffer = buffer;
  }

  /// Set the GPU renderer for accelerated updates.
  void setGpuRenderer(GpuRenderer? renderer, {int? layerId}) {
    _gpuRenderer = renderer;
    _layerId = layerId;
  }

  /// Current pixel buffer.
  PixelBuffer? get buffer => _buffer;

  /// Apply a list of pixel draws to the buffer.
  ///
  /// This is the main entry point for tool operations.
  void applyPixelDraws(List<PixelDraw> draws) {
    if (_buffer == null || draws.isEmpty) return;

    final buffer = _buffer!;

    // Apply to CPU buffer
    for (final draw in draws) {
      if (draw.x >= 0 &&
          draw.x < buffer.width &&
          draw.y >= 0 &&
          draw.y < buffer.height) {
        _setPixel(buffer, draw.x, draw.y, draw.color);
      }
    }

    // Queue GPU updates if available
    if (_gpuRenderer != null && _layerId != null) {
      final updates = draws
          .where((d) =>
              d.x >= 0 &&
              d.x < buffer.width &&
              d.y >= 0 &&
              d.y < buffer.height)
          .map((d) => PixelUpdate(
                x: d.x,
                y: d.y,
                color: _colorToInt(d.color),
              ))
          .toList();

      if (batchUpdates) {
        _pendingUpdates.addAll(updates);
      } else {
        _flushGpuUpdates(updates);
      }
    }

    // Notify listeners for repaint
    notifyListeners();
  }

  /// Erase pixels (set to transparent).
  void erasePixels(List<PixelDraw> draws) {
    if (_buffer == null || draws.isEmpty) return;

    final buffer = _buffer!;

    // Apply transparency to CPU buffer
    for (final draw in draws) {
      if (draw.x >= 0 &&
          draw.x < buffer.width &&
          draw.y >= 0 &&
          draw.y < buffer.height) {
        // For erasing, we blend toward transparency based on the draw color's alpha
        final currentColor = _getPixel(buffer, draw.x, draw.y);
        final eraseAlpha = (draw.color.a * 255).round();

        if (eraseAlpha >= 255) {
          // Full erase - set to transparent
          _setPixelRaw(buffer, draw.x, draw.y, 0, 0, 0, 0);
        } else if (eraseAlpha > 0) {
          // Partial erase - reduce alpha
          final currentAlpha = currentColor & 0xFF;
          final newAlpha = (currentAlpha * (255 - eraseAlpha) / 255).round();
          _setPixelRaw(
            buffer,
            draw.x,
            draw.y,
            (currentColor >> 24) & 0xFF,
            (currentColor >> 16) & 0xFF,
            (currentColor >> 8) & 0xFF,
            newAlpha,
          );
        }
      }
    }

    // Queue GPU updates
    if (_gpuRenderer != null && _layerId != null) {
      final updates = draws
          .where((d) =>
              d.x >= 0 &&
              d.x < buffer.width &&
              d.y >= 0 &&
              d.y < buffer.height)
          .map((d) => PixelUpdate(
                x: d.x,
                y: d.y,
                color: 0x00000000, // Transparent
              ))
          .toList();

      if (batchUpdates) {
        _pendingUpdates.addAll(updates);
      } else {
        _flushGpuUpdates(updates);
      }
    }

    notifyListeners();
  }

  /// Flush any pending GPU updates.
  ///
  /// Call this at frame boundaries or end of stroke.
  Future<void> flush() async {
    if (_pendingUpdates.isEmpty) return;

    await _flushGpuUpdates(_pendingUpdates);
    _pendingUpdates.clear();
  }

  Future<void> _flushGpuUpdates(List<PixelUpdate> updates) async {
    if (_gpuRenderer == null || _layerId == null || updates.isEmpty) return;

    try {
      await _gpuRenderer!.updatePixels(_layerId!, updates);
    } catch (e) {
      // GPU update failed, CPU buffer is still correct
      debugPrint('GPU update failed: $e');
    }
  }

  void _setPixel(PixelBuffer buffer, int x, int y, ui.Color color) {
    final offset = (y * buffer.width + x) * 4;
    final data = buffer.data;
    data[offset] = (color.r * 255).round();
    data[offset + 1] = (color.g * 255).round();
    data[offset + 2] = (color.b * 255).round();
    data[offset + 3] = (color.a * 255).round();
  }

  void _setPixelRaw(
      PixelBuffer buffer, int x, int y, int r, int g, int b, int a) {
    final offset = (y * buffer.width + x) * 4;
    final data = buffer.data;
    data[offset] = r;
    data[offset + 1] = g;
    data[offset + 2] = b;
    data[offset + 3] = a;
  }

  int _getPixel(PixelBuffer buffer, int x, int y) {
    final offset = (y * buffer.width + x) * 4;
    final data = buffer.data;
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  int _colorToInt(ui.Color color) {
    return ((color.r * 255).round() << 24) |
        ((color.g * 255).round() << 16) |
        ((color.b * 255).round() << 8) |
        (color.a * 255).round();
  }
}
