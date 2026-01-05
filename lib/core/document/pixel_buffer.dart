import 'dart:typed_data';

/// Raw RGBA pixel storage with efficient get/set operations.
///
/// Stores pixels as a flat Uint8List in RGBA format (4 bytes per pixel).
/// Coordinates are (0,0) at top-left.
class PixelBuffer {
  /// Width of the buffer in pixels.
  final int width;

  /// Height of the buffer in pixels.
  final int height;

  /// Raw pixel data in RGBA format (4 bytes per pixel).
  final Uint8List _data;

  /// Version counter that increments on any modification.
  /// Used by render objects to detect when cache invalidation is needed.
  int _version = 0;

  /// Current version of the buffer data.
  int get version => _version;

  /// Creates a new pixel buffer with the given dimensions.
  ///
  /// All pixels are initialized to transparent black (0, 0, 0, 0).
  PixelBuffer(this.width, this.height)
      : _data = Uint8List(width * height * 4);

  /// Creates a pixel buffer from existing data.
  ///
  /// The [data] must have exactly width * height * 4 bytes.
  PixelBuffer.fromData(this.width, this.height, Uint8List data)
      : _data = data {
    if (data.length != width * height * 4) {
      throw ArgumentError(
        'Data length ${data.length} does not match expected '
        '${width * height * 4} for ${width}x$height buffer',
      );
    }
  }

  /// Creates a copy of another pixel buffer.
  factory PixelBuffer.copy(PixelBuffer other) {
    return PixelBuffer.fromData(
      other.width,
      other.height,
      Uint8List.fromList(other._data),
    );
  }

  /// Total number of pixels in the buffer.
  int get length => width * height;

  /// Raw data access (read-only view).
  Uint8List get data => _data;

  /// Returns true if the coordinates are within bounds.
  bool contains(int x, int y) {
    return x >= 0 && x < width && y >= 0 && y < height;
  }

  /// Gets the byte offset for a pixel at (x, y).
  int _offset(int x, int y) => (y * width + x) * 4;

  /// Gets the RGBA values at (x, y).
  ///
  /// Returns [r, g, b, a] as a list of 4 integers (0-255).
  /// Throws if coordinates are out of bounds.
  List<int> getPixel(int x, int y) {
    _checkBounds(x, y);
    final offset = _offset(x, y);
    return [
      _data[offset],
      _data[offset + 1],
      _data[offset + 2],
      _data[offset + 3],
    ];
  }

  /// Gets the RGBA values at (x, y) as a 32-bit integer.
  ///
  /// Format: 0xRRGGBBAA
  int getPixelRaw(int x, int y) {
    _checkBounds(x, y);
    final offset = _offset(x, y);
    return (_data[offset] << 24) |
        (_data[offset + 1] << 16) |
        (_data[offset + 2] << 8) |
        _data[offset + 3];
  }

  /// Sets the RGBA values at (x, y).
  ///
  /// Values are clamped to 0-255.
  void setPixel(int x, int y, int r, int g, int b, int a) {
    _checkBounds(x, y);
    final offset = _offset(x, y);
    _data[offset] = r.clamp(0, 255);
    _data[offset + 1] = g.clamp(0, 255);
    _data[offset + 2] = b.clamp(0, 255);
    _data[offset + 3] = a.clamp(0, 255);
    _version++;
  }

  /// Sets the RGBA values at (x, y) from a 32-bit integer.
  ///
  /// Format: 0xRRGGBBAA
  void setPixelRaw(int x, int y, int rgba) {
    _checkBounds(x, y);
    final offset = _offset(x, y);
    _data[offset] = (rgba >> 24) & 0xFF;
    _data[offset + 1] = (rgba >> 16) & 0xFF;
    _data[offset + 2] = (rgba >> 8) & 0xFF;
    _data[offset + 3] = rgba & 0xFF;
    _version++;
  }

  /// Clears the buffer to transparent black.
  void clear() {
    _data.fillRange(0, _data.length, 0);
    _version++;
  }

  /// Fills the buffer with a solid color.
  void fill(int r, int g, int b, int a) {
    for (var i = 0; i < _data.length; i += 4) {
      _data[i] = r.clamp(0, 255);
      _data[i + 1] = g.clamp(0, 255);
      _data[i + 2] = b.clamp(0, 255);
      _data[i + 3] = a.clamp(0, 255);
    }
    _version++;
  }

  void _checkBounds(int x, int y) {
    if (!contains(x, y)) {
      throw RangeError('Coordinates ($x, $y) out of bounds for ${width}x$height buffer');
    }
  }

  @override
  String toString() => 'PixelBuffer(${width}x$height)';
}
