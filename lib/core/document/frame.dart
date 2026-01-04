/// An animation frame with duration metadata.
///
/// Frames represent a point in time in an animation sequence.
/// The actual pixel data for each layer at this frame is stored in [Cel]s.
class Frame {
  /// Unique identifier for this frame.
  final String id;

  /// Duration of this frame in milliseconds.
  ///
  /// A value of 0 or negative means the frame uses the sprite's default duration.
  int durationMs;

  /// Creates a new frame with the given duration.
  Frame({
    required this.id,
    this.durationMs = 100,
  });

  /// Duration as a [Duration] object.
  Duration get duration => Duration(milliseconds: durationMs);

  /// Sets the duration from a [Duration] object.
  set duration(Duration d) => durationMs = d.inMilliseconds;

  /// Creates a copy of this frame with optional overrides.
  Frame copyWith({
    String? id,
    int? durationMs,
  }) {
    return Frame(
      id: id ?? this.id,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  String toString() => 'Frame($id, ${durationMs}ms)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Frame && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
