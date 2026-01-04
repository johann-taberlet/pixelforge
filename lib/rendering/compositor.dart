import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/document/layer.dart';
import '../platform/gpu_renderer.dart';

/// Configuration for the compositor.
class CompositorConfig {
  /// Whether to use GPU acceleration when available.
  final bool useGpuAcceleration;

  /// Whether to composite only visible layers.
  final bool skipInvisibleLayers;

  /// Whether to skip fully transparent layers (opacity = 0).
  final bool skipTransparentLayers;

  const CompositorConfig({
    this.useGpuAcceleration = true,
    this.skipInvisibleLayers = true,
    this.skipTransparentLayers = true,
  });
}

/// Result of a compositing operation.
class CompositeResult {
  /// The composited image.
  final ui.Image? image;

  /// Time taken to composite in milliseconds.
  final double compositeTimeMs;

  /// Number of layers composited.
  final int layerCount;

  /// Whether GPU acceleration was used.
  final bool usedGpu;

  const CompositeResult({
    this.image,
    required this.compositeTimeMs,
    required this.layerCount,
    required this.usedGpu,
  });

  /// Whether the composite met the performance target (< 4ms).
  bool get meetsTarget => compositeTimeMs < 4.0;
}

/// GPU-accelerated layer compositor.
///
/// Composites multiple layers into a single image using the GPU
/// when available, with proper blend mode and opacity support.
///
/// Target: < 4ms for 8 layers at 1024x1024.
class Compositor {
  /// The GPU renderer to use for compositing.
  final GpuRenderer? _gpuRenderer;

  /// Configuration for the compositor.
  final CompositorConfig config;

  /// Canvas width.
  final int width;

  /// Canvas height.
  final int height;

  /// Layer textures mapped by layer ID.
  final Map<int, int> _layerTextures = {};

  /// Whether the compositor is initialized.
  bool _initialized = false;

  Compositor({
    GpuRenderer? gpuRenderer,
    required this.width,
    required this.height,
    this.config = const CompositorConfig(),
  }) : _gpuRenderer = gpuRenderer;

  /// Whether GPU compositing is available.
  bool get hasGpuSupport {
    final renderer = _gpuRenderer;
    return renderer != null && renderer.isInitialized;
  }

  /// Initialize the compositor.
  Future<void> initialize() async {
    if (_initialized) return;

    final renderer = _gpuRenderer;
    if (renderer != null && !renderer.isInitialized) {
      await renderer.initialize(width, height);
    }

    _initialized = true;
  }

  /// Dispose of compositor resources.
  Future<void> dispose() async {
    for (final textureId in _layerTextures.values) {
      await _gpuRenderer?.deleteLayer(textureId);
    }
    _layerTextures.clear();
    _initialized = false;
  }

  /// Register a layer for GPU compositing.
  ///
  /// Creates a GPU texture for the layer if needed.
  Future<int> registerLayer(Layer layer) async {
    if (!hasGpuSupport) return -1;

    if (_layerTextures.containsKey(layer.id)) {
      return _layerTextures[layer.id]!;
    }

    final textureId = await _gpuRenderer!.createLayer(layer.width, layer.height);
    _layerTextures[layer.id] = textureId;

    // Upload initial pixel data if available
    if (layer.pixelData.isNotEmpty) {
      await _gpuRenderer!.updateRegion(
        textureId,
        0,
        0,
        layer.width,
        layer.height,
        layer.pixelData,
      );
    }

    return textureId;
  }

  /// Unregister a layer and free its GPU texture.
  Future<void> unregisterLayer(int layerId) async {
    final textureId = _layerTextures.remove(layerId);
    if (textureId != null && hasGpuSupport) {
      await _gpuRenderer!.deleteLayer(textureId);
    }
  }

  /// Update a layer's GPU texture with new pixel data.
  Future<void> updateLayer(Layer layer) async {
    if (!hasGpuSupport) return;

    var textureId = _layerTextures[layer.id];
    if (textureId == null) {
      textureId = await registerLayer(layer);
    }

    await _gpuRenderer!.updateRegion(
      textureId,
      0,
      0,
      layer.width,
      layer.height,
      layer.pixelData,
    );
  }

  /// Update a region of a layer's GPU texture.
  Future<void> updateLayerRegion(
    Layer layer,
    int x,
    int y,
    int regionWidth,
    int regionHeight,
  ) async {
    if (!hasGpuSupport) return;

    final textureId = _layerTextures[layer.id];
    if (textureId == null) return;

    // Extract the region from the layer's pixel data
    final regionData = _extractRegion(
      layer.pixelData,
      layer.width,
      x,
      y,
      regionWidth,
      regionHeight,
    );

    await _gpuRenderer!.updateRegion(
      textureId,
      x,
      y,
      regionWidth,
      regionHeight,
      regionData,
    );
  }

  /// Composite layers using GPU acceleration.
  ///
  /// Layers are composited in order (first = bottom, last = top).
  Future<CompositeResult> composite(List<Layer> layers) async {
    final stopwatch = Stopwatch()..start();

    // Filter layers based on config
    final visibleLayers = layers.where((layer) {
      if (config.skipInvisibleLayers && !layer.visible) return false;
      if (config.skipTransparentLayers && layer.opacity <= 0) return false;
      return true;
    }).toList();

    if (visibleLayers.isEmpty) {
      return CompositeResult(
        image: null,
        compositeTimeMs: stopwatch.elapsedMicroseconds / 1000,
        layerCount: 0,
        usedGpu: false,
      );
    }

    // Use GPU compositing if available
    if (hasGpuSupport && config.useGpuAcceleration) {
      return _compositeGpu(visibleLayers, stopwatch);
    } else {
      return _compositeCpu(visibleLayers, stopwatch);
    }
  }

  /// GPU-accelerated compositing.
  Future<CompositeResult> _compositeGpu(
    List<Layer> layers,
    Stopwatch stopwatch,
  ) async {
    // Ensure all layers have GPU textures
    for (final layer in layers) {
      if (!_layerTextures.containsKey(layer.id)) {
        await registerLayer(layer);
      }
    }

    // Build render info list
    final renderInfos = <LayerRenderInfo>[];
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final textureId = _layerTextures[layer.id];
      if (textureId == null) continue;

      renderInfos.add(LayerRenderInfo(
        id: textureId,
        width: layer.width,
        height: layer.height,
        zIndex: i,
        opacity: layer.opacity,
        visible: layer.visible,
        blendMode: layer.blendMode.toUiBlendMode(),
      ));
    }

    // Render via GPU
    await _gpuRenderer!.render(renderInfos);

    // Get result image
    ui.Image? resultImage;
    try {
      resultImage = await _gpuRenderer!.toImage();
    } catch (_) {
      // toImage may not be implemented, fall back to CPU
      return _compositeCpu(layers, stopwatch);
    }

    stopwatch.stop();

    return CompositeResult(
      image: resultImage,
      compositeTimeMs: stopwatch.elapsedMicroseconds / 1000,
      layerCount: layers.length,
      usedGpu: true,
    );
  }

  /// CPU fallback compositing using dart:ui.
  Future<CompositeResult> _compositeCpu(
    List<Layer> layers,
    Stopwatch stopwatch,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    for (final layer in layers) {
      if (!layer.visible || layer.opacity <= 0) continue;

      // Create image from layer's pixel data
      final layerImage = await _createImageFromPixels(
        layer.pixelData,
        layer.width,
        layer.height,
      );
      if (layerImage == null) continue;

      // Apply blend mode and opacity
      final paint = ui.Paint()
        ..blendMode = layer.blendMode.toUiBlendMode()
        ..color = ui.Color.fromARGB(
          (layer.opacity * 255).round(),
          255,
          255,
          255,
        );

      canvas.drawImage(layerImage, ui.Offset.zero, paint);
      layerImage.dispose();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);

    stopwatch.stop();

    return CompositeResult(
      image: image,
      compositeTimeMs: stopwatch.elapsedMicroseconds / 1000,
      layerCount: layers.length,
      usedGpu: false,
    );
  }

  /// Create a ui.Image from raw RGBA pixel data.
  Future<ui.Image?> _createImageFromPixels(
    Uint8List pixels,
    int imageWidth,
    int imageHeight,
  ) async {
    if (pixels.isEmpty) return null;

    final completer = Completer<ui.Image>();

    ui.decodeImageFromPixels(
      pixels,
      imageWidth,
      imageHeight,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );

    return completer.future;
  }

  /// Extract a rectangular region from pixel data.
  Uint8List _extractRegion(
    Uint8List data,
    int dataWidth,
    int x,
    int y,
    int regionWidth,
    int regionHeight,
  ) {
    final result = Uint8List(regionWidth * regionHeight * 4);
    var destOffset = 0;

    for (var row = 0; row < regionHeight; row++) {
      final srcOffset = ((y + row) * dataWidth + x) * 4;
      final rowData = data.sublist(srcOffset, srcOffset + regionWidth * 4);
      result.setRange(destOffset, destOffset + regionWidth * 4, rowData);
      destOffset += regionWidth * 4;
    }

    return result;
  }
}

/// Extension to add compositing support to LayerStack.
extension CompositorLayerStackExtension on LayerStack {
  /// Composite all layers in the stack.
  Future<CompositeResult> compositeWith(Compositor compositor) async {
    return compositor.composite(layers.toList());
  }
}
