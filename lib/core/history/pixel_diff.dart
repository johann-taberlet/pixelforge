import 'dart:typed_data';

import '../document/pixel_buffer.dart';
import '../geometry/point.dart';
import 'command.dart';

/// Storage strategy for pixel changes.
enum DiffStrategy {
  /// Sparse storage: individual (x, y, oldColor, newColor) entries.
  /// Best for small, scattered changes (< ~1000 pixels).
  sparse,

  /// Run-length encoded storage for horizontal spans.
  /// Best for large fills and rectangular operations.
  runLength,

  /// Rectangular region storage with before/after buffers.
  /// Best for brush strokes and localized changes.
  rectangular,
}

/// Efficiently stores pixel changes for undo/redo.
///
/// Automatically chooses the most memory-efficient storage strategy:
/// - Sparse: For small operations (< 1000 pixels)
/// - Run-length: For large fills with few color changes
/// - Rectangular: For localized changes within a bounding box
///
/// Memory target: < 100MB for 50 undos at 1024x1024
class PixelDiff {
  /// The layer this diff applies to.
  final int layerId;

  /// Internal storage (strategy-dependent).
  final Object _storage;

  /// The storage strategy used.
  final DiffStrategy strategy;

  /// Bounding box of changes (for rectangular strategy).
  final int? x, y, width, height;

  /// Number of pixels changed.
  final int pixelCount;

  PixelDiff._({
    required this.layerId,
    required Object storage,
    required this.strategy,
    required this.pixelCount,
    this.x,
    this.y,
    this.width,
    this.height,
  }) : _storage = storage;

  /// Creates a diff from individual pixel changes.
  ///
  /// [changes] is a list of (x, y, oldColor, newColor) records.
  factory PixelDiff.fromChanges({
    required int layerId,
    required List<PixelChange> changes,
  }) {
    if (changes.isEmpty) {
      return PixelDiff._(
        layerId: layerId,
        storage: const <PixelChange>[],
        strategy: DiffStrategy.sparse,
        pixelCount: 0,
      );
    }

    // Calculate bounding box
    var minX = changes[0].x;
    var minY = changes[0].y;
    var maxX = changes[0].x;
    var maxY = changes[0].y;

    for (final c in changes) {
      if (c.x < minX) minX = c.x;
      if (c.y < minY) minY = c.y;
      if (c.x > maxX) maxX = c.x;
      if (c.y > maxY) maxY = c.y;
    }

    final boxWidth = maxX - minX + 1;
    final boxHeight = maxY - minY + 1;
    final boxArea = boxWidth * boxHeight;
    final changeCount = changes.length;

    // Strategy selection based on density
    // Sparse: each change = 16 bytes (4 ints)
    // Rectangular: boxArea * 8 bytes (2 colors per pixel)
    final sparseBytes = changeCount * 16;
    final rectBytes = boxArea * 8;

    if (changeCount < 1000 && sparseBytes <= rectBytes) {
      // Use sparse storage
      return PixelDiff._(
        layerId: layerId,
        storage: List<PixelChange>.from(changes),
        strategy: DiffStrategy.sparse,
        pixelCount: changeCount,
        x: minX,
        y: minY,
        width: boxWidth,
        height: boxHeight,
      );
    } else {
      // Use rectangular storage
      final oldColors = Uint32List(boxArea);
      final newColors = Uint32List(boxArea);

      // Initialize with transparent (no change)
      oldColors.fillRange(0, boxArea, 0);
      newColors.fillRange(0, boxArea, 0);

      for (final c in changes) {
        final idx = (c.y - minY) * boxWidth + (c.x - minX);
        oldColors[idx] = c.oldColor;
        newColors[idx] = c.newColor;
      }

      return PixelDiff._(
        layerId: layerId,
        storage: _RectStorage(oldColors, newColors),
        strategy: DiffStrategy.rectangular,
        pixelCount: changeCount,
        x: minX,
        y: minY,
        width: boxWidth,
        height: boxHeight,
      );
    }
  }

  /// Creates a diff using run-length encoding for uniform fills.
  ///
  /// Best for flood fill operations where many pixels change to the same color.
  factory PixelDiff.fromFill({
    required int layerId,
    required List<Point> pixels,
    required int oldColor,
    required int newColor,
  }) {
    if (pixels.isEmpty) {
      return PixelDiff._(
        layerId: layerId,
        storage: const <PixelChange>[],
        strategy: DiffStrategy.sparse,
        pixelCount: 0,
      );
    }

    // For uniform fills, just store the points and colors
    final points = Uint32List(pixels.length * 2);
    for (var i = 0; i < pixels.length; i++) {
      points[i * 2] = pixels[i].x;
      points[i * 2 + 1] = pixels[i].y;
    }

    return PixelDiff._(
      layerId: layerId,
      storage: _FillStorage(points, oldColor, newColor),
      strategy: DiffStrategy.runLength,
      pixelCount: pixels.length,
    );
  }

  /// Estimated memory usage in bytes.
  int get memoryBytes {
    switch (strategy) {
      case DiffStrategy.sparse:
        return (_storage as List<PixelChange>).length * 16;
      case DiffStrategy.runLength:
        final s = _storage as _FillStorage;
        return s.points.length * 4 + 8;
      case DiffStrategy.rectangular:
        final s = _storage as _RectStorage;
        return s.oldColors.length * 8;
    }
  }

  /// Applies this diff to a buffer (for redo).
  void apply(PixelBuffer buffer) {
    switch (strategy) {
      case DiffStrategy.sparse:
        for (final c in _storage as List<PixelChange>) {
          buffer.setPixelRaw(c.x, c.y, c.newColor);
        }
      case DiffStrategy.runLength:
        final s = _storage as _FillStorage;
        for (var i = 0; i < s.points.length; i += 2) {
          buffer.setPixelRaw(s.points[i], s.points[i + 1], s.newColor);
        }
      case DiffStrategy.rectangular:
        final s = _storage as _RectStorage;
        for (var dy = 0; dy < height!; dy++) {
          for (var dx = 0; dx < width!; dx++) {
            final idx = dy * width! + dx;
            final newColor = s.newColors[idx];
            if (newColor != 0 || s.oldColors[idx] != 0) {
              buffer.setPixelRaw(x! + dx, y! + dy, newColor);
            }
          }
        }
    }
  }

  /// Unapplies this diff from a buffer (for undo).
  void unapply(PixelBuffer buffer) {
    switch (strategy) {
      case DiffStrategy.sparse:
        for (final c in _storage as List<PixelChange>) {
          buffer.setPixelRaw(c.x, c.y, c.oldColor);
        }
      case DiffStrategy.runLength:
        final s = _storage as _FillStorage;
        for (var i = 0; i < s.points.length; i += 2) {
          buffer.setPixelRaw(s.points[i], s.points[i + 1], s.oldColor);
        }
      case DiffStrategy.rectangular:
        final s = _storage as _RectStorage;
        for (var dy = 0; dy < height!; dy++) {
          for (var dx = 0; dx < width!; dx++) {
            final idx = dy * width! + dx;
            final oldColor = s.oldColors[idx];
            if (oldColor != 0 || s.newColors[idx] != 0) {
              buffer.setPixelRaw(x! + dx, y! + dy, oldColor);
            }
          }
        }
    }
  }

  @override
  String toString() =>
      'PixelDiff(layer: $layerId, strategy: $strategy, pixels: $pixelCount, '
      'memory: ${(memoryBytes / 1024).toStringAsFixed(1)}KB)';
}

/// A single pixel change record.
class PixelChange {
  final int x;
  final int y;
  final int oldColor;
  final int newColor;

  const PixelChange(this.x, this.y, this.oldColor, this.newColor);
}

/// Storage for rectangular diff regions.
class _RectStorage {
  final Uint32List oldColors;
  final Uint32List newColors;

  _RectStorage(this.oldColors, this.newColors);
}

/// Storage for uniform fill operations.
class _FillStorage {
  final Uint32List points;
  final int oldColor;
  final int newColor;

  _FillStorage(this.points, this.oldColor, this.newColor);
}

/// Command that applies a pixel diff.
class PixelDiffCommand extends Command {
  final String _description;
  final PixelDiff diff;
  final PixelBuffer Function(int layerId) getBuffer;

  PixelDiffCommand({
    required String description,
    required this.diff,
    required this.getBuffer,
  }) : _description = description;

  @override
  String get description => _description;

  @override
  String get type => 'pixel_diff';

  int get memoryBytes => diff.memoryBytes;

  @override
  Future<bool> execute() async {
    diff.apply(getBuffer(diff.layerId));
    return true;
  }

  @override
  Future<bool> undo() async {
    diff.unapply(getBuffer(diff.layerId));
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'description': description,
    'layerId': diff.layerId,
  };
}
