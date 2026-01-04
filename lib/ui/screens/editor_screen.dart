import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/editor_state.dart';
import '../panels/canvas_viewport.dart';
import '../panels/colors_panel.dart';
import '../panels/layers_panel.dart';
import '../panels/toolbar_panel.dart';

/// Main editor screen with canvas and tool panels.
///
/// Layout:
/// ```
/// +----------+------------------+----------+
/// |          |                  |          |
/// | Toolbar  |  Canvas Viewport |  Layers  |
/// |          |                  |          |
/// +----------+------------------+----------+
/// |               Colors Panel             |
/// +----------------------------------------+
/// ```
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  @override
  void initState() {
    super.initState();
    // Create a default sprite on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<EditorState>();
      if (state.sprite == null) {
        state.newSprite(64, 64);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Column(
        children: [
          // Main editing area
          Expanded(
            child: Row(
              children: [
                // Left toolbar
                const RepaintBoundary(
                  child: SizedBox(
                    width: 48,
                    child: ToolbarPanel(),
                  ),
                ),
                // Divider
                const VerticalDivider(width: 1, thickness: 1),
                // Center canvas viewport
                Expanded(
                  child: RepaintBoundary(
                    child: CanvasViewport(),
                  ),
                ),
                // Divider
                const VerticalDivider(width: 1, thickness: 1),
                // Right layers panel
                const RepaintBoundary(
                  child: SizedBox(
                    width: 200,
                    child: LayersPanel(),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1, thickness: 1),
          // Bottom colors panel
          const RepaintBoundary(
            child: SizedBox(
              height: 80,
              child: ColorsPanel(),
            ),
          ),
        ],
      ),
    );
  }
}
