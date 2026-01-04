import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Whether space key is held (for pan mode).
  bool _spaceHeld = false;

  /// Focus node for keyboard input.
  final FocusNode _focusNode = FocusNode();

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
    _focusNode.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Scroll wheel zoom
      final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      _transform.zoomBy(zoomFactor, focalPoint: event.localPosition);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        setState(() => _spaceHeld = true);
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        setState(() => _spaceHeld = false);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: Consumer<EditorState>(
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
                  child: MouseRegion(
                    cursor: _spaceHeld ? SystemMouseCursors.grab : SystemMouseCursors.precise,
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
                  ),
                );
              },
            );
          },
        ),
      ),
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
    // Allow pan with single pointer when space is held, or with 2+ pointers
    final allowPan = _spaceHeld || details.pointerCount >= 2;

    if (!allowPan && details.pointerCount < 2) return;

    if (details.scale != 1.0 && details.pointerCount >= 2) {
      // Zoom with pinch gesture
      _transform.zoomBy(details.scale, focalPoint: details.localFocalPoint);
    } else if (_lastFocalPoint != null) {
      // Pan
      final delta = details.localFocalPoint - _lastFocalPoint!;
      _transform.panBy(delta);
    }

    _lastFocalPoint = details.localFocalPoint;
  }
}
