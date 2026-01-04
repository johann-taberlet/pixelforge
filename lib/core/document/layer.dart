import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Blend modes for layer compositing.
enum LayerBlendMode {
  /// Normal blending (source over).
  normal,

  /// Multiply: darkens by multiplying colors.
  multiply,

  /// Screen: lightens by inverting, multiplying, and inverting again.
  screen,

  /// Overlay: combines multiply and screen based on base color.
  overlay,

  /// Darken: keeps the darker of source and destination.
  darken,

  /// Lighten: keeps the lighter of source and destination.
  lighten,

  /// Color Dodge: brightens destination based on source.
  colorDodge,

  /// Color Burn: darkens destination based on source.
  colorBurn,

  /// Hard Light: like overlay but based on source color.
  hardLight,

  /// Soft Light: gentler version of hard light.
  softLight,

  /// Difference: subtracts darker from lighter.
  difference,

  /// Exclusion: similar to difference but lower contrast.
  exclusion,

  /// Hue: applies source hue to destination.
  hue,

  /// Saturation: applies source saturation to destination.
  saturation,

  /// Color: applies source hue and saturation to destination.
  color,

  /// Luminosity: applies source luminosity to destination.
  luminosity,
}

/// Extension to convert LayerBlendMode to dart:ui BlendMode.
extension LayerBlendModeExtension on LayerBlendMode {
  ui.BlendMode toUiBlendMode() {
    switch (this) {
      case LayerBlendMode.normal:
        return ui.BlendMode.srcOver;
      case LayerBlendMode.multiply:
        return ui.BlendMode.multiply;
      case LayerBlendMode.screen:
        return ui.BlendMode.screen;
      case LayerBlendMode.overlay:
        return ui.BlendMode.overlay;
      case LayerBlendMode.darken:
        return ui.BlendMode.darken;
      case LayerBlendMode.lighten:
        return ui.BlendMode.lighten;
      case LayerBlendMode.colorDodge:
        return ui.BlendMode.colorDodge;
      case LayerBlendMode.colorBurn:
        return ui.BlendMode.colorBurn;
      case LayerBlendMode.hardLight:
        return ui.BlendMode.hardLight;
      case LayerBlendMode.softLight:
        return ui.BlendMode.softLight;
      case LayerBlendMode.difference:
        return ui.BlendMode.difference;
      case LayerBlendMode.exclusion:
        return ui.BlendMode.exclusion;
      case LayerBlendMode.hue:
        return ui.BlendMode.hue;
      case LayerBlendMode.saturation:
        return ui.BlendMode.saturation;
      case LayerBlendMode.color:
        return ui.BlendMode.color;
      case LayerBlendMode.luminosity:
        return ui.BlendMode.luminosity;
    }
  }
}

/// Represents a single layer in the document.
class Layer {
  /// Unique identifier for this layer.
  final int id;

  /// Layer name.
  String name;

  /// Layer width in pixels.
  final int width;

  /// Layer height in pixels.
  final int height;

  /// Whether the layer is visible.
  bool visible;

  /// Whether the layer is locked (prevents editing).
  bool locked;

  /// Layer opacity (0.0 = transparent, 1.0 = opaque).
  double opacity;

  /// Blend mode for compositing.
  LayerBlendMode blendMode;

  /// Raw pixel data (RGBA, 4 bytes per pixel).
  Uint8List? _pixelData;

  /// Cached ui.Image for rendering.
  ui.Image? _cachedImage;

  /// Whether the pixel data has changed since last image cache.
  bool _isDirty = true;

  Layer({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    this.visible = true,
    this.locked = false,
    this.opacity = 1.0,
    this.blendMode = LayerBlendMode.normal,
    Uint8List? pixelData,
  }) : _pixelData = pixelData;

  /// Create a copy of this layer with optional field overrides.
  Layer copyWith({
    int? id,
    String? name,
    int? width,
    int? height,
    bool? visible,
    bool? locked,
    double? opacity,
    LayerBlendMode? blendMode,
    Uint8List? pixelData,
  }) {
    return Layer(
      id: id ?? this.id,
      name: name ?? this.name,
      width: width ?? this.width,
      height: height ?? this.height,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      pixelData: pixelData ?? (_pixelData != null ? Uint8List.fromList(_pixelData!) : null),
    );
  }

  /// Get the raw pixel data, creating it if needed.
  Uint8List get pixelData {
    _pixelData ??= Uint8List(width * height * 4);
    return _pixelData!;
  }

  /// Set pixel data and mark as dirty.
  set pixelData(Uint8List data) {
    _pixelData = data;
    _isDirty = true;
  }

  /// Whether this layer has been modified since last render.
  bool get isDirty => _isDirty;

  /// Mark the layer as needing re-render.
  void markDirty() {
    _isDirty = true;
  }

  /// Clear the dirty flag after rendering.
  void clearDirty() {
    _isDirty = false;
  }

  /// Get the color at a specific pixel.
  int getPixel(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return 0;
    }
    final offset = (y * width + x) * 4;
    final data = pixelData;
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  /// Set the color at a specific pixel.
  void setPixel(int x, int y, int color) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return;
    }
    final offset = (y * width + x) * 4;
    final data = pixelData;
    data[offset] = (color >> 24) & 0xFF; // R
    data[offset + 1] = (color >> 16) & 0xFF; // G
    data[offset + 2] = (color >> 8) & 0xFF; // B
    data[offset + 3] = color & 0xFF; // A
    _isDirty = true;
  }

  /// Clear the layer to transparent.
  void clear() {
    pixelData.fillRange(0, pixelData.length, 0);
    _isDirty = true;
  }

  /// Fill the layer with a solid color.
  void fill(int color) {
    final data = pixelData;
    final r = (color >> 24) & 0xFF;
    final g = (color >> 16) & 0xFF;
    final b = (color >> 8) & 0xFF;
    final a = color & 0xFF;

    for (var i = 0; i < data.length; i += 4) {
      data[i] = r;
      data[i + 1] = g;
      data[i + 2] = b;
      data[i + 3] = a;
    }
    _isDirty = true;
  }

  /// Create a duplicate of this layer with a new ID.
  Layer duplicate(int newId, {String? newName}) {
    return Layer(
      id: newId,
      name: newName ?? '$name copy',
      width: width,
      height: height,
      visible: visible,
      locked: locked,
      opacity: opacity,
      blendMode: blendMode,
      pixelData: Uint8List.fromList(pixelData),
    );
  }

  /// Dispose of cached resources.
  void dispose() {
    _cachedImage?.dispose();
    _cachedImage = null;
  }

  /// Serialize the layer to JSON (without pixel data).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'width': width,
        'height': height,
        'visible': visible,
        'locked': locked,
        'opacity': opacity,
        'blendMode': blendMode.index,
      };

  /// Deserialize a layer from JSON.
  factory Layer.fromJson(Map<String, dynamic> json) {
    return Layer(
      id: json['id'] as int,
      name: json['name'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      visible: json['visible'] as bool? ?? true,
      locked: json['locked'] as bool? ?? false,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blendMode: LayerBlendMode.values[json['blendMode'] as int? ?? 0],
    );
  }
}

/// Manages a collection of layers.
class LayerStack extends ChangeNotifier {
  /// The layers in the stack (bottom to top).
  final List<Layer> _layers = [];

  /// Currently selected layer ID.
  int? _selectedLayerId;

  /// Next layer ID to assign.
  int _nextId = 1;

  /// Create an empty layer stack.
  LayerStack();

  /// Get all layers (bottom to top).
  List<Layer> get layers => List.unmodifiable(_layers);

  /// Get visible layers only.
  List<Layer> get visibleLayers =>
      _layers.where((l) => l.visible).toList();

  /// Number of layers.
  int get length => _layers.length;

  /// Whether the stack is empty.
  bool get isEmpty => _layers.isEmpty;

  /// Currently selected layer.
  Layer? get selectedLayer {
    if (_selectedLayerId == null) return null;
    return getLayer(_selectedLayerId!);
  }

  /// Currently selected layer ID.
  int? get selectedLayerId => _selectedLayerId;

  /// Set the selected layer by ID.
  set selectedLayerId(int? id) {
    if (_selectedLayerId == id) return;
    _selectedLayerId = id;
    notifyListeners();
  }

  /// Get a layer by ID.
  Layer? getLayer(int id) {
    for (final layer in _layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  /// Get the index of a layer by ID.
  int indexOf(int id) {
    for (var i = 0; i < _layers.length; i++) {
      if (_layers[i].id == id) return i;
    }
    return -1;
  }

  /// Add a new layer at the top of the stack.
  Layer addLayer({
    required String name,
    required int width,
    required int height,
    int? atIndex,
  }) {
    final layer = Layer(
      id: _nextId++,
      name: name,
      width: width,
      height: height,
    );

    if (atIndex != null && atIndex >= 0 && atIndex <= _layers.length) {
      _layers.insert(atIndex, layer);
    } else {
      _layers.add(layer);
    }

    _selectedLayerId = layer.id;
    notifyListeners();
    return layer;
  }

  /// Add an existing layer to the stack.
  void addExistingLayer(Layer layer, {int? atIndex}) {
    if (layer.id >= _nextId) {
      _nextId = layer.id + 1;
    }

    if (atIndex != null && atIndex >= 0 && atIndex <= _layers.length) {
      _layers.insert(atIndex, layer);
    } else {
      _layers.add(layer);
    }

    notifyListeners();
  }

  /// Remove a layer by ID.
  Layer? removeLayer(int id) {
    final index = indexOf(id);
    if (index < 0) return null;

    final layer = _layers.removeAt(index);

    // Update selection
    if (_selectedLayerId == id) {
      if (_layers.isNotEmpty) {
        _selectedLayerId = _layers[index.clamp(0, _layers.length - 1)].id;
      } else {
        _selectedLayerId = null;
      }
    }

    notifyListeners();
    return layer;
  }

  /// Duplicate a layer.
  Layer? duplicateLayer(int id) {
    final source = getLayer(id);
    if (source == null) return null;

    final index = indexOf(id);
    final duplicate = source.duplicate(_nextId++);

    _layers.insert(index + 1, duplicate);
    _selectedLayerId = duplicate.id;
    notifyListeners();

    return duplicate;
  }

  /// Move a layer up in the stack (toward front).
  bool moveLayerUp(int id) {
    final index = indexOf(id);
    if (index < 0 || index >= _layers.length - 1) return false;

    final layer = _layers.removeAt(index);
    _layers.insert(index + 1, layer);
    notifyListeners();
    return true;
  }

  /// Move a layer down in the stack (toward back).
  bool moveLayerDown(int id) {
    final index = indexOf(id);
    if (index <= 0) return false;

    final layer = _layers.removeAt(index);
    _layers.insert(index - 1, layer);
    notifyListeners();
    return true;
  }

  /// Move a layer to a specific index.
  bool moveLayerTo(int id, int newIndex) {
    final oldIndex = indexOf(id);
    if (oldIndex < 0) return false;
    if (newIndex < 0 || newIndex >= _layers.length) return false;
    if (oldIndex == newIndex) return false;

    final layer = _layers.removeAt(oldIndex);
    _layers.insert(newIndex, layer);
    notifyListeners();
    return true;
  }

  /// Set layer visibility.
  void setLayerVisibility(int id, bool visible) {
    final layer = getLayer(id);
    if (layer == null || layer.visible == visible) return;

    layer.visible = visible;
    notifyListeners();
  }

  /// Toggle layer visibility.
  void toggleLayerVisibility(int id) {
    final layer = getLayer(id);
    if (layer == null) return;

    layer.visible = !layer.visible;
    notifyListeners();
  }

  /// Set layer opacity.
  void setLayerOpacity(int id, double opacity) {
    final layer = getLayer(id);
    if (layer == null) return;

    layer.opacity = opacity.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Set layer blend mode.
  void setLayerBlendMode(int id, LayerBlendMode blendMode) {
    final layer = getLayer(id);
    if (layer == null || layer.blendMode == blendMode) return;

    layer.blendMode = blendMode;
    notifyListeners();
  }

  /// Set layer locked state.
  void setLayerLocked(int id, bool locked) {
    final layer = getLayer(id);
    if (layer == null || layer.locked == locked) return;

    layer.locked = locked;
    notifyListeners();
  }

  /// Rename a layer.
  void renameLayer(int id, String name) {
    final layer = getLayer(id);
    if (layer == null || layer.name == name) return;

    layer.name = name;
    notifyListeners();
  }

  /// Get the current layer order as a list of IDs.
  List<int> getLayerOrder() {
    return _layers.map((l) => l.id).toList();
  }

  /// Set the layer order from a list of IDs.
  void setLayerOrder(List<int> order) {
    if (order.length != _layers.length) return;

    final newLayers = <Layer>[];
    for (final id in order) {
      final layer = getLayer(id);
      if (layer != null) {
        newLayers.add(layer);
      }
    }

    if (newLayers.length == _layers.length) {
      _layers.clear();
      _layers.addAll(newLayers);
      notifyListeners();
    }
  }

  /// Clear all layers.
  void clear() {
    for (final layer in _layers) {
      layer.dispose();
    }
    _layers.clear();
    _selectedLayerId = null;
    notifyListeners();
  }

  /// Dispose of all resources.
  @override
  void dispose() {
    for (final layer in _layers) {
      layer.dispose();
    }
    super.dispose();
  }

  /// Serialize the layer stack to JSON.
  Map<String, dynamic> toJson() => {
        'layers': _layers.map((l) => l.toJson()).toList(),
        'selectedLayerId': _selectedLayerId,
        'nextId': _nextId,
      };

  /// Deserialize a layer stack from JSON.
  factory LayerStack.fromJson(Map<String, dynamic> json) {
    final stack = LayerStack();
    final layers = (json['layers'] as List)
        .map((l) => Layer.fromJson(l as Map<String, dynamic>))
        .toList();

    for (final layer in layers) {
      stack.addExistingLayer(layer);
    }

    stack._selectedLayerId = json['selectedLayerId'] as int?;
    stack._nextId = json['nextId'] as int? ?? 1;

    return stack;
  }
}
