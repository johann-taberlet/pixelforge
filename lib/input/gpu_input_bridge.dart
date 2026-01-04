import '../platform/gpu_renderer.dart';
import '../rendering/dirty_rect_tracker.dart';
import 'gesture_coalescer.dart';
import 'input_controller.dart';

/// Connects input events directly to GPU renderer for minimal latency.
///
/// This bridge eliminates the typical Flutter path of:
///   input → setState → rebuild → paint → rasterize
///
/// Instead, it provides:
///   input → coalesce → GPU updatePixels (< 16ms target)
///
/// Usage:
/// ```dart
/// final bridge = GpuInputBridge(
///   renderer: webGpuRenderer,
///   layerId: activeLayerId,
///   dirtyTracker: dirtyRectTracker,
/// );
///
/// inputController.onInput = bridge.handleInputEvent;
/// ```
class GpuInputBridge {
  /// The GPU renderer for direct pixel writes.
  final GpuRenderer renderer;

  /// The layer ID to write pixels to.
  int layerId;

  /// Current drawing color (0xRRGGBBAA format).
  int currentColor;

  /// Dirty rectangle tracker for efficient repaints.
  final DirtyRectTracker? dirtyTracker;

  /// Layer ID as string for dirty tracker.
  String layerIdString;

  /// The stroke processor for event coalescing.
  late final StrokeProcessor _strokeProcessor;

  /// Whether drawing is currently active.
  bool _isDrawing = false;

  /// Pending pixel updates for batch GPU write.
  final List<PixelUpdate> _pendingUpdates = [];

  /// Maximum updates before forced flush.
  static const int maxPendingUpdates = 500;

  /// Callback when pixels are drawn (for UI updates).
  void Function()? onPixelsDrawn;

  GpuInputBridge({
    required this.renderer,
    required this.layerId,
    this.currentColor = 0x000000FF, // Black, fully opaque
    this.dirtyTracker,
    String? layerIdString,
    this.onPixelsDrawn,
  }) : layerIdString = layerIdString ?? layerId.toString() {
    _strokeProcessor = StrokeProcessor(
      onStroke: _handleCoalescedStroke,
      interpolationDensity: 1.0, // 1 pixel between points
    );
  }

  /// Handle an input event from [InputController].
  ///
  /// Events are coalesced and written to GPU in batches.
  void handleInputEvent(CanvasInputEvent event) {
    _strokeProcessor.handleInputEvent(event);
  }

  /// Force flush any pending updates.
  void flush() {
    _strokeProcessor.flush();
    _flushPendingUpdates();
  }

  /// Clear state without flushing.
  void clear() {
    _strokeProcessor.clear();
    _pendingUpdates.clear();
    _isDrawing = false;
  }

  void _handleCoalescedStroke(
    int pointerId,
    List<CoalescedPoint> points,
    InputEventType eventType,
  ) {
    switch (eventType) {
      case InputEventType.down:
        _isDrawing = true;
        _processPoints(points);
        break;

      case InputEventType.move:
        if (_isDrawing) {
          _processPoints(points);
        }
        break;

      case InputEventType.up:
      case InputEventType.cancel:
        if (_isDrawing) {
          _processPoints(points);
          _flushPendingUpdates();
          _isDrawing = false;
        }
        break;

      case InputEventType.hover:
        // Hover events don't draw, but could be used for cursor preview
        break;
    }
  }

  void _processPoints(List<CoalescedPoint> points) {
    for (final point in points) {
      final x = point.pixelX;
      final y = point.pixelY;

      // Bounds check
      if (x < 0 || x >= renderer.width || y < 0 || y >= renderer.height) {
        continue;
      }

      // Apply pressure to alpha if desired
      final color = _applyPressure(currentColor, point.pressure);

      // Queue pixel update
      _pendingUpdates.add(PixelUpdate(x: x, y: y, color: color));

      // Track dirty region
      dirtyTracker?.markPixelDirty(layerIdString, x, y);
    }

    // Flush if we have too many pending updates
    if (_pendingUpdates.length >= maxPendingUpdates) {
      _flushPendingUpdates();
    }
  }

  int _applyPressure(int color, double pressure) {
    // Extract alpha from color
    final alpha = color & 0xFF;

    // Apply pressure to alpha
    final newAlpha = (alpha * pressure).round().clamp(0, 255);

    // Return color with modified alpha
    return (color & 0xFFFFFF00) | newAlpha;
  }

  Future<void> _flushPendingUpdates() async {
    if (_pendingUpdates.isEmpty) return;

    // Copy and clear pending updates
    final updates = List<PixelUpdate>.from(_pendingUpdates);
    _pendingUpdates.clear();

    // Write to GPU in one batch
    await renderer.updatePixels(layerId, updates);

    // Notify listeners
    onPixelsDrawn?.call();
  }
}

/// A specialized bridge for brush tools with size and shape support.
class BrushGpuBridge extends GpuInputBridge {
  /// Brush radius in pixels.
  int brushRadius;

  /// Whether to use a circular brush (vs square).
  bool circularBrush;

  BrushGpuBridge({
    required super.renderer,
    required super.layerId,
    super.currentColor,
    super.dirtyTracker,
    super.layerIdString,
    super.onPixelsDrawn,
    this.brushRadius = 1,
    this.circularBrush = true,
  });

  @override
  void _processPoints(List<CoalescedPoint> points) {
    for (final point in points) {
      _drawBrush(point);
    }

    // Flush if we have too many pending updates
    if (_pendingUpdates.length >= GpuInputBridge.maxPendingUpdates) {
      _flushPendingUpdates();
    }
  }

  void _drawBrush(CoalescedPoint point) {
    final centerX = point.pixelX;
    final centerY = point.pixelY;
    final color = _applyPressure(currentColor, point.pressure);

    if (brushRadius <= 1) {
      // Single pixel
      _addPixelIfValid(centerX, centerY, color);
      return;
    }

    // Draw brush shape
    for (var dy = -brushRadius + 1; dy < brushRadius; dy++) {
      for (var dx = -brushRadius + 1; dx < brushRadius; dx++) {
        if (circularBrush) {
          // Check if inside circle
          if (dx * dx + dy * dy >= brushRadius * brushRadius) {
            continue;
          }
        }

        _addPixelIfValid(centerX + dx, centerY + dy, color);
      }
    }
  }

  void _addPixelIfValid(int x, int y, int color) {
    if (x < 0 || x >= renderer.width || y < 0 || y >= renderer.height) {
      return;
    }

    _pendingUpdates.add(PixelUpdate(x: x, y: y, color: color));
    dirtyTracker?.markPixelDirty(layerIdString, x, y);
  }
}

/// Performance metrics for input-to-pixel latency.
class InputLatencyMetrics {
  final List<int> _latencies = [];
  static const int maxSamples = 100;

  /// Record a latency measurement in microseconds.
  void record(int microseconds) {
    _latencies.add(microseconds);
    if (_latencies.length > maxSamples) {
      _latencies.removeAt(0);
    }
  }

  /// Average latency in milliseconds.
  double get averageMs {
    if (_latencies.isEmpty) return 0;
    return _latencies.reduce((a, b) => a + b) / _latencies.length / 1000;
  }

  /// 95th percentile latency in milliseconds.
  double get p95Ms {
    if (_latencies.isEmpty) return 0;
    final sorted = List<int>.from(_latencies)..sort();
    final p95Index = (sorted.length * 0.95).floor();
    return sorted[p95Index] / 1000;
  }

  /// Maximum latency in milliseconds.
  double get maxMs {
    if (_latencies.isEmpty) return 0;
    return _latencies.reduce((a, b) => a > b ? a : b) / 1000;
  }

  /// Whether we're meeting the <16ms target.
  bool get meetingTarget => p95Ms < 16;

  /// Clear all metrics.
  void clear() => _latencies.clear();

  @override
  String toString() =>
      'InputLatency(avg: ${averageMs.toStringAsFixed(2)}ms, '
      'p95: ${p95Ms.toStringAsFixed(2)}ms, '
      'max: ${maxMs.toStringAsFixed(2)}ms, '
      'target: ${meetingTarget ? 'MET' : 'MISSED'})';
}
