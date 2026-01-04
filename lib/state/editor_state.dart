import 'package:flutter/foundation.dart';

import '../core/document/document.dart';

/// Editor state managed by Provider.
///
/// Contains the active sprite, current frame/layer selection, and view state.
/// Available tool types in the editor.
enum ToolType {
  pencil,
  eraser,
  fill,
  colorPicker,
  selection,
  rectangle,
  ellipse,
  line,
}

class EditorState extends ChangeNotifier {
  Sprite? _sprite;
  int _currentLayerIndex = 0;
  int _currentFrameIndex = 0;
  double _zoom = 1.0;
  double _panX = 0.0;
  double _panY = 0.0;
  ToolType _activeTool = ToolType.pencil;

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

  /// Currently active tool.
  ToolType get activeTool => _activeTool;

  /// Sets the active tool.
  void setActiveTool(ToolType tool) {
    if (_activeTool == tool) return;
    _activeTool = tool;
    notifyListeners();
  }

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

  /// Creates a new sprite with the given dimensions.
  void newSprite(int width, int height) {
    _sprite = Sprite(width: width, height: height);
    _currentLayerIndex = 0;
    _currentFrameIndex = 0;
    _zoom = 1.0;
    _panX = 0.0;
    _panY = 0.0;
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
    notifyListeners();
  }

  /// Adds a new layer to the sprite.
  void addLayer() {
    if (_sprite == null) return;
    _sprite!.addLayer();
    notifyListeners();
  }

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
    notifyListeners();
  }

  /// Sets the blend mode of a layer by index.
  void setLayerBlendMode(int index, LayerBlendMode mode) {
    if (_sprite == null) return;
    if (index < 0 || index >= _sprite!.layers.length) return;
    _sprite!.layers[index].blendMode = mode;
    notifyListeners();
  }

  /// Reorders a layer from oldIndex to newIndex.
  void reorderLayer(int oldIndex, int newIndex) {
    if (_sprite == null) return;
    final layers = _sprite!.layers;
    if (oldIndex < 0 || oldIndex >= layers.length) return;
    if (newIndex < 0 || newIndex >= layers.length) return;
    if (oldIndex == newIndex) return;

    final layer = layers.removeAt(oldIndex);
    layers.insert(newIndex, layer);

    // Update current selection if needed
    if (_currentLayerIndex == oldIndex) {
      _currentLayerIndex = newIndex;
    } else if (oldIndex < _currentLayerIndex && newIndex >= _currentLayerIndex) {
      _currentLayerIndex--;
    } else if (oldIndex > _currentLayerIndex && newIndex <= _currentLayerIndex) {
      _currentLayerIndex++;
    }

    notifyListeners();
  }

  /// Duplicates the current layer.
  void duplicateCurrentLayer() {
    if (_sprite == null) return;
    if (_currentLayerIndex < 0 || _currentLayerIndex >= _sprite!.layers.length) {
      return;
    }

    final current = _sprite!.layers[_currentLayerIndex];
    final copy = current.copyWith(
      id: DateTime.now().microsecondsSinceEpoch,
      name: '${current.name} copy',
      locked: false,
    );

    _sprite!.layers.insert(_currentLayerIndex + 1, copy);
    _currentLayerIndex++;
    notifyListeners();
  }

  /// Deletes the current layer.
  void deleteCurrentLayer() {
    if (_sprite == null) return;
    if (_sprite!.layers.length <= 1) return; // Keep at least one layer
    if (_currentLayerIndex < 0 || _currentLayerIndex >= _sprite!.layers.length) {
      return;
    }

    _sprite!.layers.removeAt(_currentLayerIndex);
    if (_currentLayerIndex >= _sprite!.layers.length) {
      _currentLayerIndex = _sprite!.layers.length - 1;
    }
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
}
