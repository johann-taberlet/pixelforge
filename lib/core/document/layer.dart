/// Blend modes for compositing layers.
enum BlendMode {
  /// Normal blending (source over destination).
  normal,

  /// Multiplies color values.
  multiply,

  /// Lightens by screening colors.
  screen,

  /// Combines multiply and screen.
  overlay,

  /// Keeps the darker pixel.
  darken,

  /// Keeps the lighter pixel.
  lighten,

  /// Color dodge brightening.
  colorDodge,

  /// Color burn darkening.
  colorBurn,

  /// Hard light effect.
  hardLight,

  /// Soft light effect.
  softLight,

  /// Difference between colors.
  difference,

  /// Similar to difference, less contrast.
  exclusion,

  /// Adds source and destination.
  add,

  /// Subtracts source from destination.
  subtract,
}

/// Layer metadata for a sprite layer.
///
/// Layers define the stacking order and visual properties applied
/// when compositing. The actual pixel data is stored in [Cel]s.
class Layer {
  /// Unique identifier for this layer.
  final String id;

  /// Display name of the layer.
  String name;

  /// Whether the layer is visible during rendering.
  bool visible;

  /// Opacity from 0.0 (transparent) to 1.0 (opaque).
  double opacity;

  /// Blend mode for compositing this layer.
  BlendMode blendMode;

  /// Whether the layer is locked for editing.
  bool locked;

  /// Creates a new layer with the given properties.
  Layer({
    required this.id,
    required this.name,
    this.visible = true,
    this.opacity = 1.0,
    this.blendMode = BlendMode.normal,
    this.locked = false,
  }) {
    if (opacity < 0.0 || opacity > 1.0) {
      throw ArgumentError('Opacity must be between 0.0 and 1.0');
    }
  }

  /// Creates a copy of this layer with optional overrides.
  Layer copyWith({
    String? id,
    String? name,
    bool? visible,
    double? opacity,
    BlendMode? blendMode,
    bool? locked,
  }) {
    return Layer(
      id: id ?? this.id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      locked: locked ?? this.locked,
    );
  }

  @override
  String toString() => 'Layer($name, id: $id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Layer && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
