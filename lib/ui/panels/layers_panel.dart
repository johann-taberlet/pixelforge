import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/editor_state.dart';

/// Placeholder layers panel showing layer list.
class LayersPanel extends StatelessWidget {
  const LayersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF333333),
            child: const Text(
              'Layers',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          // Layer list
          Expanded(
            child: Consumer<EditorState>(
              builder: (context, state, _) {
                final sprite = state.sprite;
                if (sprite == null) {
                  return const Center(
                    child: Text(
                      'No sprite',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: sprite.layers.length,
                  itemBuilder: (context, index) {
                    // Display in reverse order (top layer first)
                    final layerIndex = sprite.layers.length - 1 - index;
                    final layer = sprite.layers[layerIndex];
                    final isSelected = layerIndex == state.currentLayerIndex;

                    return _LayerTile(
                      name: layer.name,
                      visible: layer.visible,
                      selected: isSelected,
                      onTap: () => state.selectLayer(layerIndex),
                      onVisibilityToggle: () =>
                          state.toggleLayerVisibility(layerIndex),
                    );
                  },
                );
              },
            ),
          ),
          // Footer buttons
          Container(
            padding: const EdgeInsets.all(4),
            color: const Color(0xFF333333),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    color: Colors.white70,
                    tooltip: 'Add layer',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () => context.read<EditorState>().addLayer(),
                  ),
                ),
                Flexible(
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.white70,
                    tooltip: 'Delete layer',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      // TODO: Implement layer deletion
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerTile extends StatelessWidget {
  final String name;
  final bool visible;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onVisibilityToggle;

  const _LayerTile({
    required this.name,
    required this.visible,
    required this.selected,
    required this.onTap,
    required this.onVisibilityToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: selected ? const Color(0xFF094771) : Colors.transparent,
        child: Row(
          children: [
            GestureDetector(
              onTap: onVisibilityToggle,
              child: Icon(
                visible ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: visible ? Colors.white70 : Colors.white30,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
