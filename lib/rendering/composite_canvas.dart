import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/document/document.dart';
import '../core/document/layer.dart' as doc;
import '../core/document/pixel_buffer.dart';

/// Widget that composites all visible layers of a sprite.
class CompositeCanvas extends StatelessWidget {
  final Sprite sprite;
  final Frame frame;
  final int version;
  final bool showCheckerboard;
  final int checkerboardSize;

  const CompositeCanvas({
    super.key,
    required this.sprite,
    required this.frame,
    required this.version,
    this.showCheckerboard = true,
    this.checkerboardSize = 8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey(version),
      size: Size(sprite.width.toDouble(), sprite.height.toDouble()),
      isComplex: true,
      willChange: true,
      painter: _CompositeCanvasPainter(
        sprite: sprite,
        frame: frame,
        version: version,
        showCheckerboard: showCheckerboard,
        checkerboardSize: checkerboardSize,
      ),
    );
  }
}

class _CompositeCanvasPainter extends CustomPainter {
  final Sprite sprite;
  final Frame frame;
  final int version;
  final bool showCheckerboard;
  final int checkerboardSize;

  _CompositeCanvasPainter({
    required this.sprite,
    required this.frame,
    required this.version,
    required this.showCheckerboard,
    required this.checkerboardSize,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final w = sprite.width;
    final h = sprite.height;

    // Draw checkerboard background
    if (showCheckerboard) {
      _drawCheckerboard(canvas, w, h);
    }

    // Composite layers from bottom to top
    for (final layer in sprite.layers) {
      if (!layer.visible || layer.opacity <= 0) continue;

      final cel = sprite.getCel(layer.id, frame.id);
      if (cel == null) continue;

      _drawBuffer(canvas, cel.buffer, layer.opacity, layer.blendMode);
    }
  }

  void _drawBuffer(ui.Canvas canvas, PixelBuffer buffer, double opacity, doc.BlendMode blendMode) {
    final paint = ui.Paint()
      ..blendMode = _toUiBlendMode(blendMode);

    for (int y = 0; y < buffer.height; y++) {
      for (int x = 0; x < buffer.width; x++) {
        final rgba = buffer.getPixel(x, y);
        final a = rgba[3];
        if (a == 0) continue;

        paint.color = ui.Color.fromARGB(
          (a * opacity).round(),
          rgba[0],
          rgba[1],
          rgba[2],
        );

        canvas.drawRect(
          ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          paint,
        );
      }
    }
  }

  void _drawCheckerboard(ui.Canvas canvas, int w, int h) {
    final sz = checkerboardSize;
    const light = ui.Color(0xFF555555);
    const dark = ui.Color(0xFF444444);
    final paint = ui.Paint();

    for (int y = 0; y < h; y += sz) {
      for (int x = 0; x < w; x += sz) {
        final isLight = ((x ~/ sz) + (y ~/ sz)) % 2 == 0;
        paint.color = isLight ? light : dark;
        canvas.drawRect(
          ui.Rect.fromLTWH(
            x.toDouble(),
            y.toDouble(),
            sz.toDouble().clamp(0, (w - x).toDouble()),
            sz.toDouble().clamp(0, (h - y).toDouble()),
          ),
          paint,
        );
      }
    }
  }

  ui.BlendMode _toUiBlendMode(doc.BlendMode mode) {
    switch (mode) {
      case doc.BlendMode.normal:
        return ui.BlendMode.srcOver;
      case doc.BlendMode.multiply:
        return ui.BlendMode.multiply;
      case doc.BlendMode.screen:
        return ui.BlendMode.screen;
      case doc.BlendMode.overlay:
        return ui.BlendMode.overlay;
      case doc.BlendMode.darken:
        return ui.BlendMode.darken;
      case doc.BlendMode.lighten:
        return ui.BlendMode.lighten;
      case doc.BlendMode.colorDodge:
        return ui.BlendMode.colorDodge;
      case doc.BlendMode.colorBurn:
        return ui.BlendMode.colorBurn;
      case doc.BlendMode.hardLight:
        return ui.BlendMode.hardLight;
      case doc.BlendMode.softLight:
        return ui.BlendMode.softLight;
      case doc.BlendMode.difference:
        return ui.BlendMode.difference;
      case doc.BlendMode.exclusion:
        return ui.BlendMode.exclusion;
      case doc.BlendMode.add:
        return ui.BlendMode.plus;
      case doc.BlendMode.subtract:
        return ui.BlendMode.difference;
    }
  }

  @override
  bool shouldRepaint(_CompositeCanvasPainter oldDelegate) {
    // Always repaint - the version check ensures Consumer rebuilds,
    // and we always want to show the latest buffer state
    return true;
  }
}
