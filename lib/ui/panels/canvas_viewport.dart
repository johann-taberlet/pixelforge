import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/document/pixel_buffer.dart';
import '../../input/gesture_coalescer.dart';
import '../../input/input_controller.dart';
import '../../rendering/canvas_transform.dart';
import '../../rendering/canvas_widget.dart';
import '../../state/editor_state.dart';
import '../../tools/tool.dart';

/// Canvas viewport with pan/zoom, input handling, and GPU-accelerated rendering.
///
/// Connects the input system to tools:
/// 1. Wraps canvas with InputController for pointer event capture
/// 2. Routes events through GestureCoalescer for frame-synchronized delivery
/// 3. Transforms screen coordinates to canvas pixel coordinates
/// 4. Dispatches coalesced events to the active tool
/// 5. Renders using PixelCanvas for GPU-accelerated display
class CanvasViewport extends StatefulWidget {
  const CanvasViewport({super.key});

  @override
  State<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends State<CanvasViewport> {
  /// Transform manager for coordinate conversion.
  final CanvasTransform _transform = CanvasTransform();

  /// Gesture coalescer for frame-synchronized event delivery.
  late GestureCoalescer _coalescer;

  /// Input controller for pointer event handling.
  late InputController _inputController;

  @override
  void initState() {
    super.initState();
    _setupInputPipeline();
  }

  void _setupInputPipeline() {
    // Create coalescer that routes events to the active tool
    _coalescer = GestureCoalescer(
      onCoalescedStroke: _handleCoalescedStroke,
      interpolationDensity: 1.0,
    );

    // Create input controller with coordinate transform
    _inputController = InputController(
      transform: _transform,
      onInput: _coalescer.handleInputEvent,
    );
  }

  void _handleCoalescedStroke(
    int pointerId,
    List<CoalescedPoint> points,
    InputEventType eventType,
  ) {
    final toolController = context.read<ToolController>();

    // Convert coalesced points to canvas input events and dispatch to tool
    for (final point in points) {
      final event = CanvasInputEvent(
        type: eventType,
        point: CanvasPoint(
          x: point.x,
          y: point.y,
          pressure: point.pressure,
          isStylus: point.isStylus,
        ),
        pointerId: pointerId,
        timestamp: point.timestamp,
      );
      toolController.handleInput(event);
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorState>(
      builder: (context, state, _) {
        final sprite = state.sprite;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Update viewport size for transform calculations
            _transform.setViewportSize(
              Size(constraints.maxWidth, constraints.maxHeight),
            );

            if (sprite != null) {
              _transform.setCanvasSize(
                Size(sprite.width.toDouble(), sprite.height.toDouble()),
              );
            }

            return GestureDetector(
              // Handle pan/zoom gestures (separate from drawing input)
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: Container(
                color: const Color(0xFF1E1E1E),
                child: Center(
                  child: sprite == null
                      ? const Text(
                          'No sprite loaded',
                          style: TextStyle(color: Colors.white38),
                        )
                      : _buildCanvasWithInput(state, sprite),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCanvasWithInput(EditorState state, dynamic sprite) {
    // Get the current cel's pixel buffer
    final cel = sprite.getCelAt(state.currentLayerIndex, state.currentFrameIndex);

    // If no cel exists, use empty buffer
    final buffer = cel?.buffer ?? PixelBuffer(sprite.width as int, sprite.height as int);

    return ListenableBuilder(
      listenable: _transform,
      builder: (context, _) {
        return Transform(
          transform: _transform.matrix,
          alignment: Alignment.topLeft,
          child: _inputController.buildInputLayer(
            child: PixelCanvas(
              buffer: buffer,
              transform: Matrix4.identity(), // Transform handled by parent
              showCheckerboard: true,
              checkerboardSize: 8,
            ),
          ),
        );
      },
    );
  }

  // Track focal point for pan gestures
  Offset? _lastFocalPoint;

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Only handle pan/zoom with 2+ pointers to not interfere with drawing
    if (details.pointerCount < 2) return;

    if (details.scale != 1.0) {
      // Zoom
      _transform.zoomBy(details.scale, focalPoint: details.localFocalPoint);
    } else if (_lastFocalPoint != null) {
      // Pan
      final delta = details.localFocalPoint - _lastFocalPoint!;
      _transform.panBy(delta);
    }

    _lastFocalPoint = details.localFocalPoint;
  }
}
