import 'dart:typed_data';
import 'dart:ui' as ui;

/// Represents a single pixel update operation.
class PixelUpdate {
  /// X coordinate in the texture.
  final int x;

  /// Y coordinate in the texture.
  final int y;

  /// RGBA color value (0xRRGGBBAA).
  final int color;

  const PixelUpdate({
    required this.x,
    required this.y,
    required this.color,
  });

  /// Extract red component (0-255).
  int get r => (color >> 24) & 0xFF;

  /// Extract green component (0-255).
  int get g => (color >> 16) & 0xFF;

  /// Extract blue component (0-255).
  int get b => (color >> 8) & 0xFF;

  /// Extract alpha component (0-255).
  int get a => color & 0xFF;

  /// Create from RGBA components.
  factory PixelUpdate.rgba({
    required int x,
    required int y,
    required int r,
    required int g,
    required int b,
    int a = 255,
  }) {
    return PixelUpdate(
      x: x,
      y: y,
      color: (r << 24) | (g << 16) | (b << 8) | a,
    );
  }
}

/// Information about a layer to be rendered.
class LayerRenderInfo {
  /// Unique identifier for this layer.
  final int id;

  /// Layer width in pixels.
  final int width;

  /// Layer height in pixels.
  final int height;

  /// Z-order for compositing (higher = on top).
  final int zIndex;

  /// Layer opacity (0.0 = transparent, 1.0 = opaque).
  final double opacity;

  /// Whether this layer is visible.
  final bool visible;

  /// Blend mode for compositing.
  final ui.BlendMode blendMode;

  /// Offset from canvas origin.
  final ui.Offset offset;

  const LayerRenderInfo({
    required this.id,
    required this.width,
    required this.height,
    this.zIndex = 0,
    this.opacity = 1.0,
    this.visible = true,
    this.blendMode = ui.BlendMode.srcOver,
    this.offset = ui.Offset.zero,
  });

  LayerRenderInfo copyWith({
    int? id,
    int? width,
    int? height,
    int? zIndex,
    double? opacity,
    bool? visible,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
  }) {
    return LayerRenderInfo(
      id: id ?? this.id,
      width: width ?? this.width,
      height: height ?? this.height,
      zIndex: zIndex ?? this.zIndex,
      opacity: opacity ?? this.opacity,
      visible: visible ?? this.visible,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
    );
  }
}

/// Abstract GPU renderer interface.
///
/// Provides platform-agnostic texture and pixel operations.
/// Implementations include WebGpuRenderer (web), MetalRenderer (iOS/macOS),
/// and VulkanRenderer (Android/Windows/Linux).
abstract class GpuRenderer {
  /// Initialize the renderer with the given canvas dimensions.
  Future<void> initialize(int width, int height);

  /// Dispose of GPU resources.
  Future<void> dispose();

  /// Whether the renderer has been initialized.
  bool get isInitialized;

  /// Create a new texture/layer with the given dimensions.
  ///
  /// Returns a unique layer ID.
  Future<int> createLayer(int width, int height);

  /// Delete a layer and free its GPU resources.
  Future<void> deleteLayer(int layerId);

  /// Update pixels in a layer.
  ///
  /// Batches multiple pixel updates for efficient GPU transfer.
  Future<void> updatePixels(int layerId, List<PixelUpdate> updates);

  /// Update a rectangular region of a layer with raw pixel data.
  ///
  /// [data] should be RGBA bytes (4 bytes per pixel).
  Future<void> updateRegion(
    int layerId,
    int x,
    int y,
    int width,
    int height,
    Uint8List data,
  );

  /// Clear a layer to the specified color.
  Future<void> clearLayer(int layerId, int color);

  /// Render all visible layers to the output.
  ///
  /// Layers are composited according to their [LayerRenderInfo].
  Future<void> render(List<LayerRenderInfo> layers);

  /// Get the rendered output as an image.
  ///
  /// Useful for saving or further processing.
  Future<ui.Image> toImage();

  /// Resize the output canvas.
  Future<void> resize(int width, int height);

  /// Current canvas width.
  int get width;

  /// Current canvas height.
  int get height;
}

/// Supported GPU renderer backends.
enum GpuBackend {
  /// WebGPU for web platform.
  webGpu,

  /// Metal for iOS and macOS.
  metal,

  /// Vulkan for Android, Windows, Linux.
  vulkan,

  /// Software fallback (CPU-based).
  software,
}

/// Factory for creating platform-appropriate GPU renderers.
abstract class GpuRendererFactory {
  /// Get the renderer backend for the current platform.
  static GpuBackend get currentBackend {
    // Platform detection will be implemented by concrete factories.
    // For now, return webGpu as default since web is the MVP target.
    return GpuBackend.webGpu;
  }

  /// Check if a specific backend is available on this platform.
  static Future<bool> isBackendAvailable(GpuBackend backend) async {
    // Will be implemented by platform-specific code.
    // WebGPU availability requires browser feature detection.
    return false;
  }

  /// Create a renderer for the current platform.
  ///
  /// Throws [UnsupportedError] if no suitable backend is available.
  static Future<GpuRenderer> create() async {
    throw UnimplementedError(
      'GpuRendererFactory.create() requires a platform-specific implementation. '
      'Use WebGpuRenderer on web or platform-specific stubs.',
    );
  }

  /// Create a renderer with a specific backend.
  ///
  /// Throws [UnsupportedError] if the backend is not available.
  static Future<GpuRenderer> createWithBackend(GpuBackend backend) async {
    throw UnimplementedError(
      'GpuRendererFactory.createWithBackend() requires a platform-specific implementation.',
    );
  }
}
