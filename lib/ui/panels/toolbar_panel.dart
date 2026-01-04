import 'package:flutter/material.dart';

/// Placeholder toolbar panel with tool buttons.
class ToolbarPanel extends StatelessWidget {
  const ToolbarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _ToolButton(icon: Icons.edit, tooltip: 'Pencil', selected: true),
          _ToolButton(icon: Icons.format_color_fill, tooltip: 'Bucket'),
          _ToolButton(icon: Icons.select_all, tooltip: 'Selection'),
          _ToolButton(icon: Icons.colorize, tooltip: 'Eyedropper'),
          const Divider(height: 16),
          _ToolButton(icon: Icons.crop_square, tooltip: 'Rectangle'),
          _ToolButton(icon: Icons.circle_outlined, tooltip: 'Ellipse'),
          _ToolButton(icon: Icons.show_chart, tooltip: 'Line'),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF094771) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: IconButton(
          icon: Icon(icon, size: 20),
          color: Colors.white70,
          onPressed: () {
            // TODO: Implement tool selection
          },
        ),
      ),
    );
  }
}
