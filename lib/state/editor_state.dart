import 'package:flutter/foundation.dart';

import '../core/document/document.dart';

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
}
