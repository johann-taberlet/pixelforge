import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

import 'input_controller.dart';

/// A coalesced stroke point with timing and interpolation info.
class CoalescedPoint {
  /// X coordinate in canvas pixels.
  final double x;

  /// Y coordinate in canvas pixels.
  final double y;

  /// Pressure from stylus (0.0 to 1.0).
  final double pressure;

  /// Whether this point is from a stylus device.
  final bool isStylus;

  /// Timestamp of the original event.
  final Duration timestamp;

  /// Whether this point was interpolated (not from an actual event).
  final bool isInterpolated;

  const CoalescedPoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.isStylus = false,
    required this.timestamp,
    this.isInterpolated = false,
  });

  /// Create from a CanvasPoint and timestamp.
  factory CoalescedPoint.fromCanvasPoint(
    CanvasPoint point,
    Duration timestamp, {
    bool isInterpolated = false,
  }) {
    return CoalescedPoint(
      x: point.x,
      y: point.y,
      pressure: point.pressure,
      isStylus: point.isStylus,
      timestamp: timestamp,
      isInterpolated: isInterpolated,
    );
  }

  /// Integer pixel coordinates.
  int get pixelX => x.floor();
  int get pixelY => y.floor();

  /// Distance to another point.
  double distanceTo(CoalescedPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() =>
      'CoalescedPoint($x, $y, pressure: $pressure${isInterpolated ? ', interpolated' : ''})';
}

/// Callback for receiving coalesced stroke points.
typedef CoalescedStrokeCallback = void Function(
  int pointerId,
  List<CoalescedPoint> points,
  InputEventType eventType,
);

/// Collects pointer events during a frame and delivers them in batches
/// at frame boundaries.
///
/// Features:
/// - Frame-synchronized event delivery via [SchedulerBinding.addPostFrameCallback]
/// - Point interpolation for smooth strokes at any drawing speed
/// - Configurable interpolation density
///
/// Usage:
/// ```dart
/// final coalescer = GestureCoalescer(
///   onCoalescedStroke: (pointerId, points, type) {
///     for (final point in points) {
///       tool.applyAt(point.pixelX, point.pixelY, point.pressure);
///     }
///   },
/// );
///
/// inputController.onInput = coalescer.handleInputEvent;
/// ```
class GestureCoalescer {
  /// Callback for coalesced stroke delivery.
  final CoalescedStrokeCallback? onCoalescedStroke;

  /// Minimum distance (in canvas pixels) between interpolated points.
  ///
  /// Lower values = smoother strokes but more points to process.
  /// Default is 1.0 (one point per pixel).
  double interpolationDensity;

  /// Whether interpolation is enabled.
  ///
  /// When disabled, only actual event points are delivered.
  bool interpolationEnabled;

  /// Maximum number of points to interpolate between two events.
  ///
  /// Prevents runaway interpolation for very fast strokes.
  int maxInterpolatedPoints;

  /// Pending events per pointer, collected during the frame.
  final Map<int, List<CanvasInputEvent>> _pendingEvents = {};

  /// Last delivered point per pointer, for interpolation.
  final Map<int, CoalescedPoint> _lastPoints = {};

  /// Whether a frame callback is currently scheduled.
  bool _callbackScheduled = false;

  GestureCoalescer({
    this.onCoalescedStroke,
    this.interpolationDensity = 1.0,
    this.interpolationEnabled = true,
    this.maxInterpolatedPoints = 100,
  });

  /// Handle an input event from [InputController].
  ///
  /// Events are collected and will be delivered at the next frame boundary.
  void handleInputEvent(CanvasInputEvent event) {
    // Add to pending events for this pointer
    _pendingEvents.putIfAbsent(event.pointerId, () => []).add(event);

    // Schedule frame callback if not already scheduled
    _scheduleFrameCallback();
  }

  /// Flush any pending events immediately.
  ///
  /// Call this when you need synchronous delivery (e.g., at stroke end).
  void flush() {
    _processFrame();
  }

  /// Clear all pending events without delivering them.
  void clear() {
    _pendingEvents.clear();
  }

  /// Reset state for a specific pointer.
  void resetPointer(int pointerId) {
    _pendingEvents.remove(pointerId);
    _lastPoints.remove(pointerId);
  }

  /// Reset all state.
  void reset() {
    _pendingEvents.clear();
    _lastPoints.clear();
  }

  void _scheduleFrameCallback() {
    if (_callbackScheduled) return;
    _callbackScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _callbackScheduled = false;
      _processFrame();
    });
  }

  void _processFrame() {
    if (_pendingEvents.isEmpty) return;

    // Process each pointer's events
    for (final entry in _pendingEvents.entries) {
      final pointerId = entry.key;
      final events = entry.value;

      if (events.isEmpty) continue;

      // Determine the event type based on the sequence
      // (prioritize up/cancel, then down, then move)
      InputEventType primaryType = InputEventType.move;
      for (final event in events) {
        if (event.type == InputEventType.down) {
          primaryType = InputEventType.down;
          // Clear last point on new stroke
          _lastPoints.remove(pointerId);
        } else if (event.type == InputEventType.up ||
            event.type == InputEventType.cancel) {
          primaryType = event.type;
        }
      }

      // Build coalesced point list
      final coalescedPoints = <CoalescedPoint>[];

      for (var i = 0; i < events.length; i++) {
        final event = events[i];
        final currentPoint = CoalescedPoint.fromCanvasPoint(
          event.point,
          event.timestamp,
        );

        // Interpolate from last point if enabled and we have a previous point
        final lastPoint = i == 0 ? _lastPoints[pointerId] : null;

        if (interpolationEnabled && lastPoint != null) {
          final interpolated = _interpolatePoints(lastPoint, currentPoint);
          coalescedPoints.addAll(interpolated);
        }

        coalescedPoints.add(currentPoint);

        // Update last point for next interpolation
        if (i == events.length - 1) {
          _lastPoints[pointerId] = currentPoint;
        }
      }

      // Clean up on stroke end
      if (primaryType == InputEventType.up ||
          primaryType == InputEventType.cancel) {
        _lastPoints.remove(pointerId);
      }

      // Deliver coalesced points
      onCoalescedStroke?.call(pointerId, coalescedPoints, primaryType);
    }

    // Clear pending events
    _pendingEvents.clear();
  }

  /// Interpolate points between [start] and [end].
  ///
  /// Returns intermediate points (not including start or end).
  List<CoalescedPoint> _interpolatePoints(
    CoalescedPoint start,
    CoalescedPoint end,
  ) {
    final distance = start.distanceTo(end);

    // No interpolation needed if points are close enough
    if (distance <= interpolationDensity) {
      return [];
    }

    // Calculate number of points to insert
    var numPoints = (distance / interpolationDensity).floor() - 1;
    numPoints = numPoints.clamp(0, maxInterpolatedPoints);

    if (numPoints <= 0) return [];

    final result = <CoalescedPoint>[];

    for (var i = 1; i <= numPoints; i++) {
      final t = i / (numPoints + 1);

      // Linear interpolation for position
      final x = _lerp(start.x, end.x, t);
      final y = _lerp(start.y, end.y, t);

      // Linear interpolation for pressure
      final pressure = _lerp(start.pressure, end.pressure, t);

      // Interpolate timestamp
      final startMs = start.timestamp.inMicroseconds;
      final endMs = end.timestamp.inMicroseconds;
      final timestamp = Duration(
        microseconds: _lerp(startMs.toDouble(), endMs.toDouble(), t).round(),
      );

      result.add(CoalescedPoint(
        x: x,
        y: y,
        pressure: pressure,
        isStylus: start.isStylus || end.isStylus,
        timestamp: timestamp,
        isInterpolated: true,
      ));
    }

    return result;
  }

  /// Linear interpolation.
  double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// A higher-level stroke processor that combines coalescing with
/// optional smoothing algorithms.
class StrokeProcessor {
  final GestureCoalescer _coalescer;

  /// Whether to apply Catmull-Rom spline smoothing.
  bool smoothingEnabled;

  /// Tension parameter for Catmull-Rom spline (0.0 to 1.0).
  double smoothingTension;

  StrokeProcessor({
    CoalescedStrokeCallback? onStroke,
    double interpolationDensity = 1.0,
    this.smoothingEnabled = false,
    this.smoothingTension = 0.5,
  }) : _coalescer = GestureCoalescer(
          onCoalescedStroke: onStroke,
          interpolationDensity: interpolationDensity,
        );

  /// Handle an input event.
  void handleInputEvent(CanvasInputEvent event) {
    _coalescer.handleInputEvent(event);
  }

  /// Flush pending events.
  void flush() => _coalescer.flush();

  /// Clear pending events.
  void clear() => _coalescer.clear();

  /// Reset all state.
  void reset() => _coalescer.reset();

  /// Access the underlying coalescer for configuration.
  GestureCoalescer get coalescer => _coalescer;
}
