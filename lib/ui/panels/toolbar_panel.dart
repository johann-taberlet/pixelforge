import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../state/editor_state.dart';

/// Toolbar panel with tool buttons.
class ToolbarPanel extends StatelessWidget {
  const ToolbarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorState>(
      builder: (context, state, _) {
        return Container(
          color: const Color(0xFF252526),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _ToolButton(
                icon: Icons.edit,
                tooltip: 'Pencil',
                selected: state.currentTool == ToolType.pencil,
                onPressed: () => state.setTool(ToolType.pencil),
              ),
              _ToolButton(
                icon: Icons.format_color_fill,
                tooltip: 'Fill Bucket',
                selected: state.currentTool == ToolType.fill,
                onPressed: () => state.setTool(ToolType.fill),
              ),
              _ToolButton(
                icon: Symbols.ink_eraser,
                tooltip: 'Eraser',
                selected: state.currentTool == ToolType.eraser,
                onPressed: () => state.setTool(ToolType.eraser),
              ),
              _ToolButton(
                icon: Icons.colorize,
                tooltip: 'Color Picker',
                selected: state.currentTool == ToolType.colorPicker,
                onPressed: () => state.setTool(ToolType.colorPicker),
              ),
              const Divider(height: 16, color: Colors.white24),
              _ToolButton(
                icon: Icons.crop_square,
                tooltip: 'Rectangle',
                selected: state.currentTool == ToolType.rectangle,
                onPressed: () => state.setTool(ToolType.rectangle),
              ),
              _ToolButton(
                icon: Icons.circle_outlined,
                tooltip: 'Ellipse',
                selected: state.currentTool == ToolType.ellipse,
                onPressed: () => state.setTool(ToolType.ellipse),
              ),
              _ToolButton(
                icon: Icons.show_chart,
                tooltip: 'Line',
                selected: state.currentTool == ToolType.line,
                onPressed: () => state.setTool(ToolType.line),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
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
          onPressed: onPressed,
        ),
      ),
    );
  }
}
