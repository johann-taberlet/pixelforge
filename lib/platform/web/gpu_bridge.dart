import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

/// JavaScript GpuRenderer class binding.
@JS('GpuRenderer')
extension type JSGpuRenderer._(JSObject _) implements JSObject {
  external factory JSGpuRenderer();

  external static JSPromise<JSBoolean> isAvailable();
  external JSPromise<JSBoolean> initialize(int width, int height);
  external int createLayer(int width, int height);
  external bool deleteLayer(int layerId);
  external void updatePixels(int layerId, JSArray<JSPixelUpdate> updates);
  external void updateRegion(
    int layerId,
    int x,
    int y,
    int width,
    int height,
    JSUint8Array data,
  );
  external void clearLayer(int layerId, int color);
  external void render(JSArray<JSLayerRenderInfo> layers);
  external JSPromise<JSObject> toImageBitmap();
  external void resize(int width, int height);
  external void dispose();
  external bool get isInitialized;
  external int get width;
  external int get height;
}

/// JavaScript pixel update object.
@JS()
@anonymous
extension type JSPixelUpdate._(JSObject _) implements JSObject {
  external factory JSPixelUpdate({
    required int x,
    required int y,
    required int color,
  });

  external int get x;
  external int get y;
  external int get color;
}

/// JavaScript layer render info object.
@JS()
@anonymous
extension type JSLayerRenderInfo._(JSObject _) implements JSObject {
  external factory JSLayerRenderInfo({
    required int id,
    required int zIndex,
    required double opacity,
    required bool visible,
  });

  external int get id;
  external int get zIndex;
  external double get opacity;
  external bool get visible;
}

/// Bridge for communicating with the JavaScript GPU renderer.
class GpuBridge {
  JSGpuRenderer? _renderer;

  /// Check if WebGPU is available.
  static Future<bool> isAvailable() async {
    final result = await JSGpuRenderer.isAvailable().toDart;
    return result.toDart;
  }

  /// Initialize the renderer with the given dimensions.
  Future<bool> initialize(int width, int height) async {
    _renderer = JSGpuRenderer();
    final result = await _renderer!.initialize(width, height).toDart;
    return result.toDart;
  }

  /// Whether the renderer has been initialized.
  bool get isInitialized => _renderer?.isInitialized ?? false;

  /// Current canvas width.
  int get width => _renderer?.width ?? 0;

  /// Current canvas height.
  int get height => _renderer?.height ?? 0;

  /// Create a new layer/texture.
  int createLayer(int width, int height) {
    _checkInitialized();
    return _renderer!.createLayer(width, height);
  }

  /// Delete a layer and free its resources.
  bool deleteLayer(int layerId) {
    _checkInitialized();
    return _renderer!.deleteLayer(layerId);
  }

  /// Update pixels in a layer.
  ///
  /// [updates] is a list of (x, y, color) where color is 0xRRGGBBAA.
  void updatePixels(int layerId, List<(int x, int y, int color)> updates) {
    _checkInitialized();
    final jsUpdates = updates
        .map((u) => JSPixelUpdate(x: u.$1, y: u.$2, color: u.$3))
        .toList()
        .toJS;
    _renderer!.updatePixels(layerId, jsUpdates);
  }

  /// Update a rectangular region with raw RGBA data.
  void updateRegion(
    int layerId,
    int x,
    int y,
    int width,
    int height,
    Uint8List data,
  ) {
    _checkInitialized();
    _renderer!.updateRegion(
      layerId,
      x,
      y,
      width,
      height,
      data.toJS,
    );
  }

  /// Clear a layer to a solid color.
  void clearLayer(int layerId, int color) {
    _checkInitialized();
    _renderer!.clearLayer(layerId, color);
  }

  /// Render all layers to the output.
  void render(List<LayerRenderData> layers) {
    _checkInitialized();
    final jsLayers = layers
        .map((l) => JSLayerRenderInfo(
              id: l.id,
              zIndex: l.zIndex,
              opacity: l.opacity,
              visible: l.visible,
            ))
        .toList()
        .toJS;
    _renderer!.render(jsLayers);
  }

  /// Resize the output canvas.
  void resize(int width, int height) {
    _checkInitialized();
    _renderer!.resize(width, height);
  }

  /// Dispose of all GPU resources.
  void dispose() {
    _renderer?.dispose();
    _renderer = null;
  }

  void _checkInitialized() {
    if (_renderer == null || !_renderer!.isInitialized) {
      throw StateError('GpuBridge not initialized. Call initialize() first.');
    }
  }
}

/// Data class for layer rendering information.
class LayerRenderData {
  final int id;
  final int zIndex;
  final double opacity;
  final bool visible;

  const LayerRenderData({
    required this.id,
    required this.zIndex,
    this.opacity = 1.0,
    this.visible = true,
  });
}
