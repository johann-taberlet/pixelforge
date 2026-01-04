import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/editor_state.dart';

/// Canvas viewport with pan/zoom and checkerboard background.
///
/// This is a placeholder that will integrate with PixelCanvas from the
/// rendering module once that's available.
class CanvasViewport extends StatelessWidget {
  const CanvasViewport({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorState>(
      builder: (context, state, _) {
        final sprite = state.sprite;

        return GestureDetector(
          onScaleStart: (_) {},
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              state.setZoom(state.zoom * details.scale);
            } else {
              state.panBy(details.focalPointDelta.dx, details.focalPointDelta.dy);
            }
          },
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: Center(
              child: sprite == null
                  ? const Text(
                      'No sprite loaded',
                      style: TextStyle(color: Colors.white38),
                    )
                  : Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(state.panX, state.panY, 0, 0)
                        ..scaleByDouble(state.zoom, state.zoom, 1, 0),
                      alignment: Alignment.center,
                      child: _CanvasPlaceholder(
                        width: sprite.width,
                        height: sprite.height,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder canvas showing a checkerboard pattern.
///
/// Will be replaced with PixelCanvas once rendering module is merged.
class _CanvasPlaceholder extends StatelessWidget {
  final int width;
  final int height;

  const _CanvasPlaceholder({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.toDouble(),
      height: height.toDouble(),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
      ),
      child: CustomPaint(
        painter: _CheckerboardPainter(),
        size: Size(width.toDouble(), height.toDouble()),
      ),
    );
  }
}

/// Paints a checkerboard pattern for transparency visualization.
class _CheckerboardPainter extends CustomPainter {
  static const _lightColor = Color(0xFFCCCCCC);
  static const _darkColor = Color(0xFF999999);
  static const _tileSize = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()..color = _lightColor;
    final darkPaint = Paint()..color = _darkColor;

    final cols = (size.width / _tileSize).ceil();
    final rows = (size.height / _tileSize).ceil();

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final isLight = (row + col) % 2 == 0;
        final rect = Rect.fromLTWH(
          col * _tileSize,
          row * _tileSize,
          _tileSize,
          _tileSize,
        );
        canvas.drawRect(rect, isLight ? lightPaint : darkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
