import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../rendering/composite_canvas.dart';
import '../../state/editor_state.dart';

/// Canvas viewport with pan/zoom and checkerboard background.
///
/// Supports both web and mobile input:
/// - Web: Mouse wheel to zoom, middle-click or Space+drag to pan
/// - Mobile: Pinch to zoom, two-finger pan
class CanvasViewport extends StatefulWidget {
  const CanvasViewport({super.key});

  @override
  State<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends State<CanvasViewport> {
  bool _spacePressed = false;
  bool _isPanning = false;
  bool _isDrawing = false;
  double _lastScale = 1.0;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Convert screen position to canvas pixel coordinates.
  Offset? _screenToCanvas(Offset screenPos, EditorState state) {
    final sprite = state.sprite;
    if (sprite == null) return null;

    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final localPos = renderBox.globalToLocal(screenPos);
    final size = renderBox.size;

    // Account for centering, pan, and zoom
    final centerX = size.width / 2 + state.panX;
    final centerY = size.height / 2 + state.panY;
    final canvasWidth = sprite.width * state.zoom;
    final canvasHeight = sprite.height * state.zoom;
    final canvasLeft = centerX - canvasWidth / 2;
    final canvasTop = centerY - canvasHeight / 2;

    final canvasX = (localPos.dx - canvasLeft) / state.zoom;
    final canvasY = (localPos.dy - canvasTop) / state.zoom;

    return Offset(canvasX, canvasY);
  }

  void _handleToolInput(PointerEvent event, EditorState state) {
    if (_spacePressed || _isPanning) return;

    final canvasPos = _screenToCanvas(event.position, state);
    if (canvasPos == null) return;

    final x = canvasPos.dx.floor();
    final y = canvasPos.dy.floor();
    final sprite = state.sprite;
    if (sprite == null) return;
    if (x < 0 || x >= sprite.width || y < 0 || y >= sprite.height) return;

    switch (state.currentTool) {
      case ToolType.pencil:
        state.drawPixel(x, y, state.currentColor);
      case ToolType.eraser:
        state.clearPixel(x, y);
      case ToolType.colorPicker:
        final buffer = state.currentBuffer;
        if (buffer != null && buffer.contains(x, y)) {
          final rgba = buffer.getPixel(x, y);
          if (rgba[3] > 0) {
            state.setColor(Color.fromARGB(rgba[3], rgba[0], rgba[1], rgba[2]));
          }
        }
      case ToolType.fill:
        state.floodFill(x, y);
      case ToolType.rectangle:
      case ToolType.ellipse:
      case ToolType.line:
        // TODO: Implement shape tools
        break;
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      setState(() {
        _spacePressed = event is KeyDownEvent || event is KeyRepeatEvent;
      });
    }
  }

  void _handlePointerSignal(PointerSignalEvent event, EditorState state) {
    if (event is PointerScaleEvent) {
      // Trackpad pinch gesture → zoom
      state.setZoom(state.zoom * event.scale);
    } else if (event is PointerScrollEvent) {
      // Trackpad two-finger scroll = pan, Mouse wheel = zoom
      final isTrackpad = event.kind == PointerDeviceKind.trackpad;

      if (isTrackpad) {
        // Trackpad two-finger scroll → pan
        state.panBy(-event.scrollDelta.dx, -event.scrollDelta.dy);
      } else {
        // Mouse wheel → zoom
        final delta = event.scrollDelta.dy;
        final zoomFactor = delta > 0 ? 0.9 : 1.1;
        state.setZoom(state.zoom * zoomFactor);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorState>(
      builder: (context, state, _) {
        final sprite = state.sprite;

        return KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Listener(
            onPointerSignal: (event) => _handlePointerSignal(event, state),
            onPointerDown: (event) {
              _focusNode.requestFocus();
              // Middle mouse button starts pan
              if (event.buttons == kMiddleMouseButton) {
                setState(() => _isPanning = true);
              } else if (event.buttons == kPrimaryButton && !_spacePressed) {
                // Primary button starts drawing
                setState(() => _isDrawing = true);
                _handleToolInput(event, state);
              }
            },
            onPointerUp: (event) {
              setState(() {
                _isPanning = false;
                _isDrawing = false;
              });
            },
            onPointerMove: (event) {
              // Pan with middle mouse or space+left click
              if (_isPanning || (_spacePressed && event.buttons == kPrimaryButton)) {
                state.panBy(event.delta.dx, event.delta.dy);
              } else if (_isDrawing && event.buttons == kPrimaryButton) {
                // Drawing with primary button
                _handleToolInput(event, state);
              }
            },
            child: GestureDetector(
              // Mobile: pinch to zoom, two-finger pan
              onScaleStart: (details) {
                _lastScale = 1.0;
              },
              onScaleUpdate: (details) {
                // Pinch zoom
                if (details.scale != 1.0) {
                  final scaleDelta = details.scale / _lastScale;
                  state.setZoom(state.zoom * scaleDelta);
                  _lastScale = details.scale;
                }
                // Two-finger pan (when not zooming)
                if (details.pointerCount >= 2 || _spacePressed) {
                  state.panBy(details.focalPointDelta.dx, details.focalPointDelta.dy);
                }
              },
              child: MouseRegion(
                cursor: _spacePressed || _isPanning
                    ? SystemMouseCursors.grab
                    : SystemMouseCursors.basic,
                child: Container(
                  key: _canvasKey,
                  color: const Color(0xFF1E1E1E),
                  child: Center(
                    child: (sprite == null || state.currentFrame == null)
                        ? const Text(
                            'No sprite loaded',
                            style: TextStyle(color: Colors.white38),
                          )
                        : Transform(
                            transform: Matrix4.identity()
                              ..translate(state.panX, state.panY)
                              ..scale(state.zoom, state.zoom),
                            alignment: Alignment.center,
                            child: RepaintBoundary(
                              child: SizedBox(
                                width: sprite.width.toDouble(),
                                height: sprite.height.toDouble(),
                                child: CompositeCanvas(
                                  sprite: sprite,
                                  frame: state.currentFrame!,
                                  version: state.renderVersion,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
