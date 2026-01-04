import '../core/color/color.dart';
import '../core/document/pixel_buffer.dart';
import '../input/input_controller.dart';
import 'tool.dart';

/// Callback for when a color is picked.
typedef ColorPickedCallback = void Function(Color color, ColorPickerTarget target);

/// Which color slot the picked color should be assigned to.
enum ColorPickerTarget {
  /// Set as the foreground (primary) color.
  foreground,

  /// Set as the background (secondary) color.
  background,
}

/// Tool for sampling colors from the canvas.
///
/// Features:
/// - Click to sample color at point
/// - Left click = foreground, right click = background (configurable)
/// - Preview sampled color on hover
/// - Works across all visible layers (uses composite buffer)
class ColorPickerTool extends Tool {
  /// Callback when a color is successfully picked.
  final ColorPickedCallback? onColorPicked;

  /// Callback for hover preview (shows color under cursor).
  final void Function(Color? color)? onHoverPreview;

  /// The buffer to sample colors from.
  ///
  /// This should be the composited view of all visible layers.
  PixelBuffer? _buffer;

  /// Whether to use pressure sensitivity for picking.
  ///
  /// When enabled, low pressure picks background color.
  bool usePressureForTarget;

  /// Pressure threshold for switching to background color.
  double pressureThreshold;

  /// The last sampled color (for preview).
  Color? _lastSampledColor;

  /// Whether alt/option key was held (for background color).
  bool _altKeyPressed = false;

  ColorPickerTool({
    this.onColorPicked,
    this.onHoverPreview,
    this.usePressureForTarget = false,
    this.pressureThreshold = 0.5,
  });

  @override
  String get id => 'color_picker';

  @override
  String get name => 'Color Picker';

  /// Sets the buffer to sample colors from.
  ///
  /// Should be called whenever the canvas content changes.
  void setBuffer(PixelBuffer buffer) {
    _buffer = buffer;
  }

  /// Set whether alt key is pressed (for background color picking).
  void setAltKeyPressed(bool pressed) {
    _altKeyPressed = pressed;
  }

  /// Sample color at the given canvas coordinates.
  ///
  /// Returns null if coordinates are out of bounds or buffer is not set.
  Color? sampleAt(int x, int y) {
    if (_buffer == null) return null;
    if (!_buffer!.contains(x, y)) return null;

    final pixel = _buffer!.getPixel(x, y);
    return Color.rgba(pixel[0], pixel[1], pixel[2], pixel[3]);
  }

  /// Determine the target (foreground/background) based on input.
  ColorPickerTarget _determineTarget(CanvasInputEvent event) {
    // Alt key = background color
    if (_altKeyPressed) {
      return ColorPickerTarget.background;
    }

    // Pressure-based selection
    if (usePressureForTarget && event.point.pressure < pressureThreshold) {
      return ColorPickerTarget.background;
    }

    // Default to foreground
    return ColorPickerTarget.foreground;
  }

  @override
  void onStart(CanvasInputEvent event) {
    super.onStart(event);
    _pickColor(event);
  }

  @override
  void onUpdate(CanvasInputEvent event) {
    // Continue picking while dragging (allows exploring colors)
    _pickColor(event);
  }

  @override
  void onEnd(CanvasInputEvent event) {
    // Final pick at release point
    _pickColor(event);
    super.onEnd(event);
  }

  @override
  void onHover(CanvasInputEvent event) {
    // Show preview of color under cursor
    final color = sampleAt(event.point.pixelX, event.point.pixelY);
    _lastSampledColor = color;
    onHoverPreview?.call(color);
  }

  @override
  void onCancel() {
    _lastSampledColor = null;
    onHoverPreview?.call(null);
    super.onCancel();
  }

  @override
  void onDeactivate() {
    _lastSampledColor = null;
    onHoverPreview?.call(null);
    super.onDeactivate();
  }

  void _pickColor(CanvasInputEvent event) {
    final color = sampleAt(event.point.pixelX, event.point.pixelY);
    if (color == null) return;

    _lastSampledColor = color;
    final target = _determineTarget(event);
    onColorPicked?.call(color, target);
  }

  /// Gets the last sampled color (useful for UI display).
  Color? get lastSampledColor => _lastSampledColor;
}

/// A color picker that samples from multiple layers and returns
/// the topmost non-transparent pixel.
class LayerAwareColorPicker {
  /// Buffers for each layer, ordered from bottom to top.
  final List<PixelBuffer> _layers = [];

  /// Visibility flags for each layer.
  final List<bool> _visibility = [];

  /// Sets the layers to sample from.
  ///
  /// [layers] should be ordered from bottom to top.
  /// [visibility] indicates which layers are visible.
  void setLayers(List<PixelBuffer> layers, List<bool> visibility) {
    _layers.clear();
    _visibility.clear();
    _layers.addAll(layers);
    _visibility.addAll(visibility);
  }

  /// Sample the topmost visible, non-transparent color at (x, y).
  ///
  /// Returns null if all layers are transparent at this point.
  Color? sampleAt(int x, int y) {
    // Sample from top to bottom, return first non-transparent pixel
    for (var i = _layers.length - 1; i >= 0; i--) {
      if (!_visibility[i]) continue;

      final buffer = _layers[i];
      if (!buffer.contains(x, y)) continue;

      final pixel = buffer.getPixel(x, y);
      if (pixel[3] > 0) {
        return Color.rgba(pixel[0], pixel[1], pixel[2], pixel[3]);
      }
    }

    return null;
  }

  /// Sample with alpha blending from all visible layers.
  ///
  /// Composites all layers at the point using normal blending.
  Color sampleComposited(int x, int y) {
    double r = 0, g = 0, b = 0, a = 0;

    // Composite from bottom to top
    for (var i = 0; i < _layers.length; i++) {
      if (!_visibility[i]) continue;

      final buffer = _layers[i];
      if (!buffer.contains(x, y)) continue;

      final pixel = buffer.getPixel(x, y);
      final srcA = pixel[3] / 255.0;

      if (srcA > 0) {
        final srcR = pixel[0] / 255.0;
        final srcG = pixel[1] / 255.0;
        final srcB = pixel[2] / 255.0;

        // Porter-Duff source-over
        final outA = srcA + a * (1 - srcA);
        if (outA > 0) {
          r = (srcR * srcA + r * a * (1 - srcA)) / outA;
          g = (srcG * srcA + g * a * (1 - srcA)) / outA;
          b = (srcB * srcA + b * a * (1 - srcA)) / outA;
          a = outA;
        }
      }
    }

    return Color.rgba(
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
      (a * 255).round().clamp(0, 255),
    );
  }
}
