import 'dart:math' as math;

/// An immutable RGBA color with HSV conversion support.
class Color {
  /// Red component (0-255).
  final int r;

  /// Green component (0-255).
  final int g;

  /// Blue component (0-255).
  final int b;

  /// Alpha component (0-255), where 255 is fully opaque.
  final int a;

  const Color(this.r, this.g, this.b, [this.a = 255]);

  /// Creates a color from RGBA values (0-255).
  const Color.rgba(this.r, this.g, this.b, this.a);

  /// Creates a fully opaque color from RGB values.
  const Color.rgb(this.r, this.g, this.b) : a = 255;

  /// Creates a color from a 32-bit RGBA integer (0xRRGGBBAA).
  factory Color.fromRgba32(int rgba) {
    return Color.rgba(
      (rgba >> 24) & 0xFF,
      (rgba >> 16) & 0xFF,
      (rgba >> 8) & 0xFF,
      rgba & 0xFF,
    );
  }

  /// Creates a color from a 32-bit ARGB integer (0xAARRGGBB).
  factory Color.fromArgb32(int argb) {
    return Color.rgba(
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
      (argb >> 24) & 0xFF,
    );
  }

  /// Creates a color from HSV values.
  /// [h] is hue in degrees (0-360).
  /// [s] is saturation (0.0-1.0).
  /// [v] is value/brightness (0.0-1.0).
  /// [a] is alpha (0-255).
  factory Color.fromHsv(double h, double s, double v, [int a = 255]) {
    h = h % 360;
    if (h < 0) h += 360;
    s = s.clamp(0.0, 1.0);
    v = v.clamp(0.0, 1.0);

    final c = v * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = v - c;

    double r1, g1, b1;

    if (h < 60) {
      r1 = c;
      g1 = x;
      b1 = 0;
    } else if (h < 120) {
      r1 = x;
      g1 = c;
      b1 = 0;
    } else if (h < 180) {
      r1 = 0;
      g1 = c;
      b1 = x;
    } else if (h < 240) {
      r1 = 0;
      g1 = x;
      b1 = c;
    } else if (h < 300) {
      r1 = x;
      g1 = 0;
      b1 = c;
    } else {
      r1 = c;
      g1 = 0;
      b1 = x;
    }

    return Color.rgba(
      ((r1 + m) * 255).round(),
      ((g1 + m) * 255).round(),
      ((b1 + m) * 255).round(),
      a,
    );
  }

  /// Parses a hex color string.
  /// Supports formats: #RGB, #RGBA, #RRGGBB, #RRGGBBAA (with or without #).
  factory Color.fromHex(String hex) {
    hex = hex.replaceFirst('#', '').toUpperCase();

    if (hex.length == 3) {
      // #RGB -> #RRGGBB
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}FF';
    } else if (hex.length == 4) {
      // #RGBA -> #RRGGBBAA
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}';
    } else if (hex.length == 6) {
      // #RRGGBB -> #RRGGBBFF
      hex = '${hex}FF';
    } else if (hex.length != 8) {
      throw FormatException('Invalid hex color: $hex');
    }

    return Color.fromRgba32(int.parse(hex, radix: 16));
  }

  /// Converts to 32-bit RGBA integer (0xRRGGBBAA).
  int toRgba32() => (r << 24) | (g << 16) | (b << 8) | a;

  /// Converts to 32-bit ARGB integer (0xAARRGGBB).
  int toArgb32() => (a << 24) | (r << 16) | (g << 8) | b;

  /// Converts to HSV representation.
  /// Returns (hue: 0-360, saturation: 0-1, value: 0-1).
  ({double h, double s, double v}) toHsv() {
    final r1 = r / 255;
    final g1 = g / 255;
    final b1 = b / 255;

    final cMax = math.max(r1, math.max(g1, b1));
    final cMin = math.min(r1, math.min(g1, b1));
    final delta = cMax - cMin;

    double h;
    if (delta == 0) {
      h = 0;
    } else if (cMax == r1) {
      h = 60 * (((g1 - b1) / delta) % 6);
    } else if (cMax == g1) {
      h = 60 * (((b1 - r1) / delta) + 2);
    } else {
      h = 60 * (((r1 - g1) / delta) + 4);
    }

    if (h < 0) h += 360;

    final s = cMax == 0 ? 0.0 : delta / cMax;
    final v = cMax;

    return (h: h, s: s, v: v);
  }

  /// Converts to hex string (e.g., "#FF0000" or "#FF0000FF").
  String toHex({bool includeAlpha = false}) {
    final hex = StringBuffer('#');
    hex.write(r.toRadixString(16).padLeft(2, '0').toUpperCase());
    hex.write(g.toRadixString(16).padLeft(2, '0').toUpperCase());
    hex.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
    if (includeAlpha) {
      hex.write(a.toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return hex.toString();
  }

  /// Creates a copy with modified components.
  Color copyWith({int? r, int? g, int? b, int? a}) {
    return Color.rgba(
      r ?? this.r,
      g ?? this.g,
      b ?? this.b,
      a ?? this.a,
    );
  }

  /// Returns the color with modified alpha.
  Color withAlpha(int alpha) => copyWith(a: alpha);

  /// Returns the color with opacity (0.0-1.0).
  Color withOpacity(double opacity) =>
      copyWith(a: (opacity.clamp(0.0, 1.0) * 255).round());

  /// Luminance value (0.0-1.0) using standard coefficients.
  double get luminance => (0.299 * r + 0.587 * g + 0.114 * b) / 255;

  /// Whether this is a light color (luminance > 0.5).
  bool get isLight => luminance > 0.5;

  /// Whether this is a dark color (luminance <= 0.5).
  bool get isDark => luminance <= 0.5;

  /// Linearly interpolates between two colors.
  static Color lerp(Color a, Color b, double t) {
    t = t.clamp(0.0, 1.0);
    return Color.rgba(
      (a.r + (b.r - a.r) * t).round(),
      (a.g + (b.g - a.g) * t).round(),
      (a.b + (b.b - a.b) * t).round(),
      (a.a + (b.a - a.a) * t).round(),
    );
  }

  // ========== Common Colors ==========

  static const Color transparent = Color.rgba(0, 0, 0, 0);
  static const Color black = Color.rgb(0, 0, 0);
  static const Color white = Color.rgb(255, 255, 255);
  static const Color red = Color.rgb(255, 0, 0);
  static const Color green = Color.rgb(0, 255, 0);
  static const Color blue = Color.rgb(0, 0, 255);
  static const Color yellow = Color.rgb(255, 255, 0);
  static const Color cyan = Color.rgb(0, 255, 255);
  static const Color magenta = Color.rgb(255, 0, 255);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Color && r == other.r && g == other.g && b == other.b && a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'Color($r, $g, $b, $a)';
}
