import 'package:flutter/material.dart';

/// Placeholder colors panel with color palette.
class ColorsPanel extends StatelessWidget {
  const ColorsPanel({super.key});

  // Basic 16-color palette
  static const _palette = [
    Color(0xFF000000), Color(0xFF1D2B53), Color(0xFF7E2553), Color(0xFF008751),
    Color(0xFFAB5236), Color(0xFF5F574F), Color(0xFFC2C3C7), Color(0xFFFFF1E8),
    Color(0xFFFF004D), Color(0xFFFFA300), Color(0xFFFFEC27), Color(0xFF00E436),
    Color(0xFF29ADFF), Color(0xFF83769C), Color(0xFFFF77A8), Color(0xFFFFCCAA),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // Foreground/background colors
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ColorSwatch(color: Colors.white, size: 28, label: 'FG'),
              const SizedBox(height: 4),
              _ColorSwatch(color: Colors.black, size: 28, label: 'BG'),
            ],
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 1),
          const SizedBox(width: 16),
          // Palette grid
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _palette
                  .map((c) => _ColorSwatch(color: c, size: 24))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final double size;
  final String? label;

  const _ColorSwatch({
    required this.color,
    required this.size,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label ?? '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      child: GestureDetector(
        onTap: () {
          // TODO: Implement color selection
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
