import 'pixel_buffer.dart';

/// A cel represents the intersection of a layer and frame.
///
/// Cels hold the actual pixel data for a specific layer at a specific
/// frame in the animation timeline. Not every layer/frame combination
/// needs a cel - empty intersections simply have no cel.
class Cel {
  /// The layer ID this cel belongs to.
  final String layerId;

  /// The frame ID this cel belongs to.
  final String frameId;

  /// The pixel data for this cel.
  ///
  /// Multiple cels can share the same PixelBuffer for linked cels
  /// (e.g., when a layer doesn't change across frames).
  PixelBuffer buffer;

  /// X offset of this cel within the canvas.
  int offsetX;

  /// Y offset of this cel within the canvas.
  int offsetY;

  /// Creates a new cel at the given layer/frame intersection.
  Cel({
    required this.layerId,
    required this.frameId,
    required this.buffer,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  /// Width of the cel's pixel buffer.
  int get width => buffer.width;

  /// Height of the cel's pixel buffer.
  int get height => buffer.height;

  /// Creates a copy of this cel with a copied buffer.
  Cel copy() {
    return Cel(
      layerId: layerId,
      frameId: frameId,
      buffer: PixelBuffer.copy(buffer),
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  /// Creates a copy with optional overrides.
  ///
  /// Note: This shares the buffer by default. Use [copy] for a deep copy.
  Cel copyWith({
    String? layerId,
    String? frameId,
    PixelBuffer? buffer,
    int? offsetX,
    int? offsetY,
  }) {
    return Cel(
      layerId: layerId ?? this.layerId,
      frameId: frameId ?? this.frameId,
      buffer: buffer ?? this.buffer,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
    );
  }

  /// Unique key for this cel's position in the timeline.
  String get key => '$layerId:$frameId';

  @override
  String toString() => 'Cel($layerId, $frameId, ${buffer.width}x${buffer.height})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cel && layerId == other.layerId && frameId == other.frameId;

  @override
  int get hashCode => Object.hash(layerId, frameId);
}
