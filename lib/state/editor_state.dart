import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/document/document.dart';
import '../core/document/layer.dart' as doc;
import '../core/document/pixel_buffer.dart';

/// Tool types available in the editor.
enum ToolType { pencil, eraser, fill, colorPicker, rectangle, ellipse, line }

/// Editor state managed by Provider.
///
/// Contains the active sprite, current frame/layer selection, and view state.
class EditorState extends ChangeNotifier {
  Sprite? _sprite;
  int _currentLayerIndex = 0;
  int _currentFrameIndex = 0;
  double _zoom = 1.0;
  double _panX = 0.0;
  double _panY = 0.0;
  ToolType _currentTool = ToolType.pencil;
  Color _currentColor = const Color(0xFF000000);
  int _renderVersion = 0;

  /// Version counter that increments on every render-affecting change.
  int get renderVersion => _renderVersion;

  /// Notify listeners and increment render version.
  void _notifyRenderChange() {
    _renderVersion++;
    notifyListeners();
  }

  /// The active sprite document.
  Sprite? get sprite => _sprite;

  /// Current layer index.
  int get currentLayerIndex => _currentLayerIndex;

  /// Current frame index.
  int get currentFrameIndex => _currentFrameIndex;

  /// Current zoom level (1.0 = 100%).
  double get zoom => _zoom;

  /// Horizontal pan offset.
  double get panX => _panX;

  /// Vertical pan offset.
  double get panY => _panY;

  /// Current layer (if sprite is loaded).
  Layer? get currentLayer {
    if (_sprite == null || _sprite!.layers.isEmpty) return null;
    if (_currentLayerIndex >= _sprite!.layers.length) return null;
    return _sprite!.layers[_currentLayerIndex];
  }

  /// Current frame (if sprite is loaded).
  Frame? get currentFrame {
    if (_sprite == null || _sprite!.frames.isEmpty) return null;
    if (_currentFrameIndex >= _sprite!.frames.length) return null;
    return _sprite!.frames[_currentFrameIndex];
  }

  /// Gets the current cel's pixel buffer, or null if none exists.
  PixelBuffer? get currentBuffer {
    if (_sprite == null) return null;
    final layer = currentLayer;
    final frame = currentFrame;
    if (layer == null || frame == null) return null;
    return _sprite!.getCel(layer.id, frame.id)?.buffer;
  }

  /// Creates a new sprite with the given dimensions.
  void newSprite(int width, int height) {
    _sprite = Sprite(width: width, height: height);
    _currentLayerIndex = 0;
    _currentFrameIndex = 0;
    _zoom = 16.0;  // Start zoomed in so pixels are visible
    _panX = 0.0;
    _panY = 0.0;
    // Create a cel for the default layer/frame
    final layer = _sprite!.layers.first;
    final frame = _sprite!.frames.first;
    _sprite!.createCel(layer.id, frame.id);
    notifyListeners();
  }

  /// Sets the active sprite.
  void setSprite(Sprite sprite) {
    _sprite = sprite;
    _currentLayerIndex = 0;
    _currentFrameIndex = 0;
    notifyListeners();
  }

  /// Selects a layer by index.
  void selectLayer(int index) {
    if (_sprite == null) return;
    if (index < 0 || index >= _sprite!.layers.length) return;
    _currentLayerIndex = index;
    notifyListeners();
  }

  /// Selects a frame by index.
  void selectFrame(int index) {
    if (_sprite == null) return;
    if (index < 0 || index >= _sprite!.frames.length) return;
    _currentFrameIndex = index;
    notifyListeners();
  }

  /// Sets the zoom level.
  void setZoom(double zoom) {
    _zoom = zoom.clamp(0.1, 64.0);
    notifyListeners();
  }

  /// Sets the pan offset.
  void setPan(double x, double y) {
    _panX = x;
    _panY = y;
    notifyListeners();
  }

  /// Adjusts zoom by a delta factor.
  void zoomBy(double factor) {
    setZoom(_zoom * factor);
  }

  /// Pans by a delta.
  void panBy(double dx, double dy) {
    _panX += dx;
    _panY += dy;
    notifyListeners();
  }

  /// Toggles visibility of a layer by index.
  void toggleLayerVisibility(int index) {
    if (_sprite == null) return;
    if (index < 0 || index >= _sprite!.layers.length) return;
    _sprite!.layers[index].visible = !_sprite!.layers[index].visible;
    _notifyRenderChange();
  }

  /// Adds a new layer to the sprite below the current layer.
  void addLayer() {
    if (_sprite == null) return;

    // Create new layer
    final id = 'layer_${DateTime.now().microsecondsSinceEpoch}';
    final newLayer = Layer(
      id: id,
      name: 'Layer ${_sprite!.layers.length + 1}',
    );

    // Insert below current layer (at current index, pushing current up)
    _sprite!.insertLayer(_currentLayerIndex, newLayer);

    // Create cels for all existing frames
    for (final frame in _sprite!.frames) {
      _sprite!.createCel(newLayer.id, frame.id);
    }

    // Keep selection on the new layer (which is now at _currentLayerIndex)
    notifyListeners();
  }

  /// Deletes the current layer.
  void deleteLayer() {
    if (_sprite == null) return;
    if (_sprite!.layers.length <= 1) return; // Keep at least one layer

    final layer = currentLayer;
    if (layer == null) return;
    if (layer.locked) return; // Cannot delete a locked layer

    _sprite!.removeLayer(layer.id);

    // Adjust current layer index
    if (_currentLayerIndex >= _sprite!.layers.length) {
      _currentLayerIndex = _sprite!.layers.length - 1;
    }
    notifyListeners();
  }

  /// Alias for deleteLayer for compatibility.
  void deleteCurrentLayer() => deleteLayer();

  /// Toggles lock state of a layer by index.
  void toggleLayerLock(int index) {
    if (_sprite == null) return;
    if (index < 0 || index >= _sprite!.layers.length) return;
    _sprite!.layers[index].locked = !_sprite!.layers[index].locked;
    notifyListeners();
  }

  /// Sets the opacity of a layer by index.
  void setLayerOpacity(int index, double opacity) {
    if (_sprite == null) return;
    if (index < 0 || index >= _sprite!.layers.length) return;
    _sprite!.layers[index].opacity = opacity.clamp(0.0, 1.0);
    _notifyRenderChange();
  }

  /// Sets the blend mode of a layer by index.
  void setLayerBlendMode(int index, doc.BlendMode mode) {
    if (_sprite == null) return;
    if (index < 0 || index >= _sprite!.layers.length) return;
    _sprite!.layers[index].blendMode = mode;
    _notifyRenderChange();
  }

  /// Reorders a layer from oldIndex to newIndex.
  void reorderLayer(int oldIndex, int newIndex) {
    if (_sprite == null) return;
    final layerCount = _sprite!.layers.length;
    if (oldIndex < 0 || oldIndex >= layerCount) return;
    if (newIndex < 0 || newIndex >= layerCount) return;
    if (oldIndex == newIndex) return;

    // Use Sprite's moveLayer which handles the internal list
    _sprite!.moveLayer(oldIndex, newIndex);

    // Update current selection to follow the moved layer
    if (_currentLayerIndex == oldIndex) {
      _currentLayerIndex = newIndex;
    } else if (oldIndex < _currentLayerIndex && newIndex >= _currentLayerIndex) {
      _currentLayerIndex--;
    } else if (oldIndex > _currentLayerIndex && newIndex <= _currentLayerIndex) {
      _currentLayerIndex++;
    }

    _notifyRenderChange();
  }

  /// Duplicates the current layer.
  void duplicateCurrentLayer() {
    if (_sprite == null) return;
    if (_currentLayerIndex < 0 || _currentLayerIndex >= _sprite!.layers.length) {
      return;
    }

    final current = _sprite!.layers[_currentLayerIndex];
    final copy = current.copyWith(
      id: 'layer_${DateTime.now().microsecondsSinceEpoch}',
      name: '${current.name} copy',
      locked: false,
    );

    _sprite!.layers.insert(_currentLayerIndex + 1, copy);

    // Also duplicate cels for all frames
    for (final frame in _sprite!.frames) {
      final cel = _sprite!.getCel(current.id, frame.id);
      if (cel != null) {
        _sprite!.createCel(copy.id, frame.id);
        final newCel = _sprite!.getCel(copy.id, frame.id);
        if (newCel != null) {
          // Copy pixel data
          for (int y = 0; y < cel.buffer.height; y++) {
            for (int x = 0; x < cel.buffer.width; x++) {
              final rgba = cel.buffer.getPixel(x, y);
              newCel.buffer.setPixel(x, y, rgba[0], rgba[1], rgba[2], rgba[3]);
            }
          }
        }
      }
    }

    _currentLayerIndex++;
    notifyListeners();
  }

  /// Moves current layer up in the stack.
  void moveCurrentLayerUp() {
    if (_sprite == null) return;
    if (_currentLayerIndex >= _sprite!.layers.length - 1) return;
    reorderLayer(_currentLayerIndex, _currentLayerIndex + 1);
  }

  /// Moves current layer down in the stack.
  void moveCurrentLayerDown() {
    if (_sprite == null) return;
    if (_currentLayerIndex <= 0) return;
    reorderLayer(_currentLayerIndex, _currentLayerIndex - 1);
  }

  /// Current tool type.
  ToolType get currentTool => _currentTool;

  /// Sets the current tool.
  void setTool(ToolType tool) {
    if (_currentTool != tool) {
      _currentTool = tool;
      notifyListeners();
    }
  }

  /// Current drawing color.
  Color get currentColor => _currentColor;

  /// Sets the current color.
  void setColor(Color color) {
    if (_currentColor != color) {
      _currentColor = color;
      notifyListeners();
    }
  }

  /// Whether the current layer is locked.
  bool get isCurrentLayerLocked => currentLayer?.locked ?? false;

  /// Draws a pixel at (x, y) with the given color.
  void drawPixel(int x, int y, Color color) {
    if (isCurrentLayerLocked) return;
    final buffer = currentBuffer;
    if (buffer == null) return;
    if (!buffer.contains(x, y)) return;

    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final a = (color.a * 255).round();
    buffer.setPixel(x, y, r, g, b, a);
    _notifyRenderChange();
  }

  /// Draws multiple pixels.
  void drawPixels(List<({int x, int y, Color color})> pixels) {
    if (isCurrentLayerLocked) return;
    final buffer = currentBuffer;
    if (buffer == null) return;

    for (final p in pixels) {
      if (buffer.contains(p.x, p.y)) {
        final r = (p.color.r * 255).round();
        final g = (p.color.g * 255).round();
        final b = (p.color.b * 255).round();
        final a = (p.color.a * 255).round();
        buffer.setPixel(p.x, p.y, r, g, b, a);
      }
    }
    _notifyRenderChange();
  }

  /// Clears a pixel (sets to transparent).
  void clearPixel(int x, int y) {
    if (isCurrentLayerLocked) return;
    final buffer = currentBuffer;
    if (buffer == null) return;
    if (!buffer.contains(x, y)) return;
    buffer.setPixel(x, y, 0, 0, 0, 0);
    _notifyRenderChange();
  }

  /// Flood fills from (x, y) with the current color.
  void floodFill(int x, int y) {
    if (isCurrentLayerLocked) return;
    final buffer = currentBuffer;
    if (buffer == null) return;
    if (!buffer.contains(x, y)) return;

    final targetColor = buffer.getPixelRaw(x, y);
    final fillColor = _colorToRaw(_currentColor);

    // Don't fill if same color
    if (targetColor == fillColor) return;

    // Simple scanline flood fill
    final visited = <int>{};
    final stack = <int>[y * buffer.width + x];

    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      if (visited.contains(pos)) continue;

      final px = pos % buffer.width;
      final py = pos ~/ buffer.width;

      if (!buffer.contains(px, py)) continue;
      if (buffer.getPixelRaw(px, py) != targetColor) continue;

      visited.add(pos);
      buffer.setPixelRaw(px, py, fillColor);

      // Add neighbors
      if (px > 0) stack.add(pos - 1);
      if (px < buffer.width - 1) stack.add(pos + 1);
      if (py > 0) stack.add(pos - buffer.width);
      if (py < buffer.height - 1) stack.add(pos + buffer.width);
    }

    _notifyRenderChange();
  }

  /// Converts Color to raw RGBA int (RRGGBBAA format).
  int _colorToRaw(Color c) {
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    final a = (c.a * 255).round();
    return (r << 24) | (g << 16) | (b << 8) | a;
  }
}
