import 'dart:typed_data';
import 'dart:ui' as ui;

import '../gpu_renderer.dart';
import 'gpu_bridge.dart';

/// WebGPU implementation of the GpuRenderer interface.
///
/// Uses JavaScript interop to communicate with the WebGPU API
/// through [GpuBridge]. Falls back to Canvas 2D when WebGPU
/// is unavailable in the browser.
class WebGpuRenderer implements GpuRenderer {
  final GpuBridge _bridge = GpuBridge();
  int _width = 0;
  int _height = 0;
  bool _initialized = false;

  /// Layer ID to LayerRenderInfo mapping for tracking layer metadata.
  final Map<int, LayerRenderInfo> _layerInfo = {};

  /// Check if WebGPU is available in the current browser.
  static Future<bool> isAvailable() => GpuBridge.isAvailable();

  @override
  Future<void> initialize(int width, int height) async {
    _width = width;
    _height = height;
    await _bridge.initialize(width, height);
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    _bridge.dispose();
    _layerInfo.clear();
    _initialized = false;
  }

  @override
  bool get isInitialized => _initialized && _bridge.isInitialized;

  @override
  int get width => _width;

  @override
  int get height => _height;

  @override
  Future<int> createLayer(int width, int height) async {
    _checkInitialized();
    final id = _bridge.createLayer(width, height);
    _layerInfo[id] = LayerRenderInfo(
      id: id,
      width: width,
      height: height,
    );
    return id;
  }

  @override
  Future<void> deleteLayer(int layerId) async {
    _checkInitialized();
    _bridge.deleteLayer(layerId);
    _layerInfo.remove(layerId);
  }

  @override
  Future<void> updatePixels(int layerId, List<PixelUpdate> updates) async {
    _checkInitialized();
    final bridgeUpdates = updates
        .map((u) => (u.x, u.y, u.color))
        .toList();
    _bridge.updatePixels(layerId, bridgeUpdates);
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
    _checkInitialized();
    _bridge.updateRegion(layerId, x, y, width, height, data);
  }

  @override
  Future<void> clearLayer(int layerId, int color) async {
    _checkInitialized();
    _bridge.clearLayer(layerId, color);
  }

  @override
  Future<void> render(List<LayerRenderInfo> layers) async {
    _checkInitialized();
    final renderData = layers
        .map((l) => LayerRenderData(
              id: l.id,
              zIndex: l.zIndex,
              opacity: l.opacity,
              visible: l.visible,
            ))
        .toList();
    _bridge.render(renderData);
  }

  @override
  Future<ui.Image> toImage() async {
    _checkInitialized();
    // Note: This is a placeholder. Full implementation would require
    // reading back the ImageBitmap from JS and converting to ui.Image.
    // This may require platform channels or additional interop.
    throw UnimplementedError(
      'toImage() requires additional implementation for web platform. '
      'Consider using the JavaScript toImageBitmap() directly.',
    );
  }

  @override
  Future<void> resize(int width, int height) async {
    _checkInitialized();
    _width = width;
    _height = height;
    _bridge.resize(width, height);
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'WebGpuRenderer not initialized. Call initialize() first.',
      );
    }
  }
}
