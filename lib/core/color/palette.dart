import 'color.dart';

/// A collection of indexed colors for pixel art.
///
/// Palettes support a maximum of 256 colors (indexed color mode).
/// The first color (index 0) is typically used as the transparent color.
class Palette {
  /// Display name of the palette.
  String name;

  /// The indexed colors in this palette.
  final List<Color> _colors;

  /// Maximum number of colors in a palette.
  static const int maxColors = 256;

  Palette({required this.name, List<Color>? colors})
      : _colors = colors != null ? List<Color>.from(colors) : [] {
    if (_colors.length > maxColors) {
      throw ArgumentError('Palette cannot exceed $maxColors colors');
    }
  }

  /// Creates a default palette with basic colors.
  factory Palette.defaultPalette() {
    return Palette(
      name: 'Default',
      colors: [
        Color.transparent,
        Color.black,
        Color.white,
        Color.red,
        Color.green,
        Color.blue,
        Color.yellow,
        Color.cyan,
        Color.magenta,
        const Color.rgb(128, 128, 128), // Gray
        const Color.rgb(192, 192, 192), // Light gray
        const Color.rgb(64, 64, 64), // Dark gray
        const Color.rgb(128, 0, 0), // Dark red
        const Color.rgb(0, 128, 0), // Dark green
        const Color.rgb(0, 0, 128), // Dark blue
        const Color.rgb(128, 128, 0), // Olive
      ],
    );
  }

  /// Creates a grayscale palette with the specified number of shades.
  factory Palette.grayscale({int shades = 16, String name = 'Grayscale'}) {
    if (shades < 2 || shades > maxColors) {
      throw ArgumentError('Shades must be between 2 and $maxColors');
    }

    final colors = <Color>[];
    for (var i = 0; i < shades; i++) {
      final v = (255 * i / (shades - 1)).round();
      colors.add(Color.rgb(v, v, v));
    }

    return Palette(name: name, colors: colors);
  }

  /// Unmodifiable view of colors.
  List<Color> get colors => List.unmodifiable(_colors);

  /// Number of colors in the palette.
  int get length => _colors.length;

  /// Whether the palette is empty.
  bool get isEmpty => _colors.isEmpty;

  /// Whether the palette is at maximum capacity.
  bool get isFull => _colors.length >= maxColors;

  /// Gets the color at the specified index.
  Color operator [](int index) => _colors[index];

  /// Sets the color at the specified index.
  void operator []=(int index, Color color) {
    if (index < 0 || index >= _colors.length) {
      throw RangeError.index(index, _colors);
    }
    _colors[index] = color;
  }

  /// Adds a color to the palette.
  /// Returns the index of the added color.
  /// Throws if palette is full.
  int add(Color color) {
    if (isFull) {
      throw StateError('Palette is full ($maxColors colors)');
    }
    _colors.add(color);
    return _colors.length - 1;
  }

  /// Inserts a color at the specified index.
  void insert(int index, Color color) {
    if (isFull) {
      throw StateError('Palette is full ($maxColors colors)');
    }
    _colors.insert(index, color);
  }

  /// Removes the color at the specified index.
  Color removeAt(int index) => _colors.removeAt(index);

  /// Removes the last color from the palette.
  Color removeLast() => _colors.removeLast();

  /// Clears all colors from the palette.
  void clear() => _colors.clear();

  /// Finds the index of a color, or -1 if not found.
  int indexOf(Color color) => _colors.indexOf(color);

  /// Whether the palette contains the specified color.
  bool contains(Color color) => _colors.contains(color);

  /// Finds the closest color in the palette to the given color.
  /// Returns the index of the closest color.
  /// Uses Euclidean distance in RGB space.
  int findClosest(Color color) {
    if (_colors.isEmpty) {
      throw StateError('Palette is empty');
    }

    var closestIndex = 0;
    var closestDistance = double.infinity;

    for (var i = 0; i < _colors.length; i++) {
      final c = _colors[i];
      final dr = c.r - color.r;
      final dg = c.g - color.g;
      final db = c.b - color.b;
      final distance = dr * dr + dg * dg + db * db;

      if (distance < closestDistance) {
        closestDistance = distance.toDouble();
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Creates a copy of this palette.
  Palette clone() => Palette(name: name, colors: _colors);

  /// Swaps two colors in the palette.
  void swap(int i, int j) {
    if (i < 0 || i >= _colors.length || j < 0 || j >= _colors.length) {
      throw RangeError('Index out of bounds');
    }
    final temp = _colors[i];
    _colors[i] = _colors[j];
    _colors[j] = temp;
  }

  /// Sorts colors by hue.
  void sortByHue() {
    _colors.sort((a, b) {
      final hsvA = a.toHsv();
      final hsvB = b.toHsv();
      return hsvA.h.compareTo(hsvB.h);
    });
  }

  /// Sorts colors by luminance.
  void sortByLuminance() {
    _colors.sort((a, b) => a.luminance.compareTo(b.luminance));
  }

  @override
  String toString() => 'Palette($name, ${_colors.length} colors)';
}
