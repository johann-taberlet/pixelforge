import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/editor_state.dart';

/// Toolbar panel with tool selection buttons.
///
/// Features:
/// - Visual feedback for selected tool
/// - Wired to EditorState.setActiveTool()
class ToolbarPanel extends StatelessWidget {
  const ToolbarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      child: Consumer<EditorState>(
        builder: (context, state, _) {
          return Column(
            children: [
              const SizedBox(height: 8),
              _ToolButton(
                icon: Icons.edit,
                tooltip: 'Pencil',
                selected: state.activeTool == ToolType.pencil,
                onTap: () => state.setActiveTool(ToolType.pencil),
              ),
              _ToolButton(
                icon: Icons.auto_fix_high,
                tooltip: 'Eraser',
                selected: state.activeTool == ToolType.eraser,
                onTap: () => state.setActiveTool(ToolType.eraser),
              ),
              _ToolButton(
                icon: Icons.format_color_fill,
                tooltip: 'Fill',
                selected: state.activeTool == ToolType.fill,
                onTap: () => state.setActiveTool(ToolType.fill),
              ),
              _ToolButton(
                icon: Icons.colorize,
                tooltip: 'Color Picker',
                selected: state.activeTool == ToolType.colorPicker,
                onTap: () => state.setActiveTool(ToolType.colorPicker),
              ),
              const Divider(height: 16, color: Colors.white24),
              _ToolButton(
                icon: Icons.select_all,
                tooltip: 'Selection',
                selected: state.activeTool == ToolType.selection,
                onTap: () => state.setActiveTool(ToolType.selection),
              ),
              const Divider(height: 16, color: Colors.white24),
              _ToolButton(
                icon: Icons.crop_square,
                tooltip: 'Rectangle',
                selected: state.activeTool == ToolType.rectangle,
                onTap: () => state.setActiveTool(ToolType.rectangle),
              ),
              _ToolButton(
                icon: Icons.circle_outlined,
                tooltip: 'Ellipse',
                selected: state.activeTool == ToolType.ellipse,
                onTap: () => state.setActiveTool(ToolType.ellipse),
              ),
              _ToolButton(
                icon: Icons.show_chart,
                tooltip: 'Line',
                selected: state.activeTool == ToolType.line,
                onTap: () => state.setActiveTool(ToolType.line),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF094771) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: selected
                ? Border.all(color: const Color(0xFF1177BB), width: 1)
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}
