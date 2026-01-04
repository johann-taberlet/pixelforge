import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/document/layer.dart' as doc;
import '../../state/editor_state.dart';

/// Layer panel with full layer management capabilities.
///
/// Features:
/// - Layer list with thumbnails
/// - Drag-to-reorder
/// - Visibility/lock toggles
/// - Opacity slider
/// - Blend mode dropdown
/// - Add/delete/duplicate buttons
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
          _buildHeader(),
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

                return ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: sprite.layers.length,
                  onReorder: (oldIndex, newIndex) {
                    // Convert visual indices to layer indices (reversed)
                    final layerCount = sprite.layers.length;
                    final oldLayerIndex = layerCount - 1 - oldIndex;
                    final newLayerIndex = layerCount - 1 - newIndex;
                    state.reorderLayer(oldLayerIndex, newLayerIndex);
                  },
                  itemBuilder: (context, index) {
                    // Display in reverse order (top layer first)
                    final layerIndex = sprite.layers.length - 1 - index;
                    final layer = sprite.layers[layerIndex];
                    final isSelected = layerIndex == state.currentLayerIndex;

                    return _LayerTile(
                      key: ValueKey(layer.id),
                      index: index,
                      layer: layer,
                      selected: isSelected,
                      onTap: () => state.selectLayer(layerIndex),
                      onVisibilityToggle: () =>
                          state.toggleLayerVisibility(layerIndex),
                      onLockToggle: () => state.toggleLayerLock(layerIndex),
                      onOpacityChange: (opacity) =>
                          state.setLayerOpacity(layerIndex, opacity),
                      onBlendModeChange: (mode) =>
                          state.setLayerBlendMode(layerIndex, mode),
                    );
                  },
                );
              },
            ),
          ),
          // Footer buttons
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      color: const Color(0xFF333333),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            color: Colors.white70,
            tooltip: 'Add layer',
            onPressed: () => context.read<EditorState>().addLayer(),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            color: Colors.white70,
            tooltip: 'Duplicate layer',
            onPressed: () => context.read<EditorState>().duplicateCurrentLayer(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.white70,
            tooltip: 'Delete layer',
            onPressed: () => context.read<EditorState>().deleteCurrentLayer(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            color: Colors.white70,
            tooltip: 'Move layer up',
            onPressed: () => context.read<EditorState>().moveCurrentLayerUp(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            color: Colors.white70,
            tooltip: 'Move layer down',
            onPressed: () => context.read<EditorState>().moveCurrentLayerDown(),
          ),
        ],
      ),
    );
  }
}

class _LayerTile extends StatefulWidget {
  final int index;
  final doc.Layer layer;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onVisibilityToggle;
  final VoidCallback onLockToggle;
  final ValueChanged<double> onOpacityChange;
  final ValueChanged<doc.LayerBlendMode> onBlendModeChange;

  const _LayerTile({
    required super.key,
    required this.index,
    required this.layer,
    required this.selected,
    required this.onTap,
    required this.onVisibilityToggle,
    required this.onLockToggle,
    required this.onOpacityChange,
    required this.onBlendModeChange,
  });

  @override
  State<_LayerTile> createState() => _LayerTileState();
}

class _LayerTileState extends State<_LayerTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMainRow(),
        if (_isExpanded && widget.selected) _buildExpandedControls(),
      ],
    );
  }

  Widget _buildMainRow() {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: widget.selected ? const Color(0xFF094771) : Colors.transparent,
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: widget.index,
              child: const Icon(
                Icons.drag_handle,
                size: 16,
                color: Colors.white30,
              ),
            ),
            const SizedBox(width: 4),
            // Thumbnail placeholder
            _buildThumbnail(),
            const SizedBox(width: 8),
            // Layer name
            Expanded(
              child: Text(
                widget.layer.name,
                style: TextStyle(
                  color: widget.layer.locked ? Colors.white38 : Colors.white70,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Visibility toggle
            GestureDetector(
              onTap: widget.onVisibilityToggle,
              child: Icon(
                widget.layer.visible ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: widget.layer.visible ? Colors.white70 : Colors.white30,
              ),
            ),
            const SizedBox(width: 8),
            // Lock toggle
            GestureDetector(
              onTap: widget.onLockToggle,
              child: Icon(
                widget.layer.locked ? Icons.lock : Icons.lock_open,
                size: 16,
                color: widget.layer.locked ? Colors.orange : Colors.white30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    // Placeholder thumbnail - in full implementation would show layer preview
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white10,
        border: Border.all(color: Colors.white24, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Icon(
        Icons.image,
        size: 14,
        color: Colors.white24,
      ),
    );
  }

  Widget _buildExpandedControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opacity slider
          Row(
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  'Opacity',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: widget.layer.opacity,
                    min: 0,
                    max: 1,
                    onChanged: widget.onOpacityChange,
                    activeColor: Colors.blue,
                    inactiveColor: Colors.white24,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${(widget.layer.opacity * 100).round()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Blend mode dropdown
          Row(
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  'Blend',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<doc.LayerBlendMode>(
                    value: widget.layer.blendMode,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF333333),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    underline: const SizedBox(),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white54,
                      size: 18,
                    ),
                    items: doc.LayerBlendMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_blendModeLabel(mode)),
                      );
                    }).toList(),
                    onChanged: (mode) {
                      if (mode != null) {
                        widget.onBlendModeChange(mode);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _blendModeLabel(doc.LayerBlendMode mode) {
    switch (mode) {
      case doc.LayerBlendMode.normal:
        return 'Normal';
      case doc.LayerBlendMode.multiply:
        return 'Multiply';
      case doc.LayerBlendMode.screen:
        return 'Screen';
      case doc.LayerBlendMode.overlay:
        return 'Overlay';
      case doc.LayerBlendMode.darken:
        return 'Darken';
      case doc.LayerBlendMode.lighten:
        return 'Lighten';
      case doc.LayerBlendMode.colorDodge:
        return 'Color Dodge';
      case doc.LayerBlendMode.colorBurn:
        return 'Color Burn';
      case doc.LayerBlendMode.hardLight:
        return 'Hard Light';
      case doc.LayerBlendMode.softLight:
        return 'Soft Light';
      case doc.LayerBlendMode.difference:
        return 'Difference';
      case doc.LayerBlendMode.exclusion:
        return 'Exclusion';
      case doc.LayerBlendMode.hue:
        return 'Hue';
      case doc.LayerBlendMode.saturation:
        return 'Saturation';
      case doc.LayerBlendMode.color:
        return 'Color';
      case doc.LayerBlendMode.luminosity:
        return 'Luminosity';
    }
  }
}
