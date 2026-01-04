/// Blend modes for compositing layers.
enum BlendMode {
  /// Normal alpha blending.
  normal,

  /// Multiply: darkens by multiplying colors.
  multiply,

  /// Screen: lightens by inverting, multiplying, and inverting again.
  screen,

  /// Overlay: combines multiply and screen based on base color.
  overlay,

  /// Darken: keeps the darker of two colors.
  darken,

  /// Lighten: keeps the lighter of two colors.
  lighten,

  /// Color dodge: brightens base color to reflect blend color.
  colorDodge,

  /// Color burn: darkens base color to reflect blend color.
  colorBurn,

  /// Hard light: combines multiply and screen based on blend color.
  hardLight,

  /// Soft light: softer version of hard light.
  softLight,

  /// Difference: subtracts darker from lighter color.
  difference,

  /// Exclusion: similar to difference but lower contrast.
  exclusion,

  /// Add: adds color values (clamped).
  add,

  /// Subtract: subtracts blend from base (clamped).
  subtract,
}
