import 'dart:typed_data';
import 'dart:ui' as ui;

import '../gpu_renderer.dart';

/// Vulkan renderer stub for Android/Windows/Linux.
///
/// This is a placeholder implementation that will be completed in Phase 10.
/// All methods throw [UnsupportedError] until Vulkan integration is implemented.
class VulkanRenderer implements GpuRenderer {
  static const String _unsupportedMessage =
      'VulkanRenderer is not yet implemented. Coming in Phase 10.';

  final bool _initialized = false;
  final int _width = 0;
  final int _height = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  int get width => _width;

  @override
  int get height => _height;

  @override
  Future<void> initialize(int width, int height) async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> dispose() async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<int> createLayer(int width, int height) async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> deleteLayer(int layerId) async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> updatePixels(int layerId, List<PixelUpdate> updates) async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> updateRegion(
    int layerId,
    int x,
    int y,
    int width,
    int height,
    Uint8List data,
  ) async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> clearLayer(int layerId, int color) async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> render(List<LayerRenderInfo> layers) async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<ui.Image> toImage() async {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> resize(int width, int height) async {
    throw UnsupportedError(_unsupportedMessage);
  }
}
