import 'dart:ui' as ui;

import 'dirty_rect_tracker.dart';

/// Reason for layer cache invalidation.
enum InvalidationReason {
  /// Layer pixels were modified.
  pixelsChanged,

  /// Layer visibility changed.
  visibilityChanged,

  /// Layer opacity changed.
  opacityChanged,

  /// Layer blend mode changed.
  blendModeChanged,

  /// Layer was reordered in the stack.
  reordered,

  /// Layer was deleted.
  deleted,

  /// Layer was added.
  added,

  /// Full invalidation requested.
  full,
}

/// Cached GPU texture for a layer.
class LayerTexture {
  /// The layer ID.
  final String layerId;

  /// Cached GPU image (null if invalidated).
  ui.Image? _image;

  /// Version number for cache validation.
  int _version = 0;

  /// Whether the cache is valid.
  bool _valid = false;

  /// Last composite timestamp.
  DateTime? _lastComposite;

  /// Dirty regions pending update.
  final List<ui.Rect> _dirtyRegions = [];

  LayerTexture(this.layerId);

  /// Gets the cached image, or null if cache is invalid.
  ui.Image? get image => _valid ? _image : null;

  /// Whether the cache is currently valid.
  bool get isValid => _valid && _image != null;

  /// Current version number.
  int get version => _version;

  /// Time since last composite.
  Duration? get timeSinceComposite => _lastComposite == null
      ? null
      : DateTime.now().difference(_lastComposite!);

  /// Dirty regions that need updating.
  List<ui.Rect> get dirtyRegions => List.unmodifiable(_dirtyRegions);

  /// Whether there are dirty regions pending.
  bool get hasDirtyRegions => _dirtyRegions.isNotEmpty;

  /// Updates the cached image.
  void updateImage(ui.Image image) {
    _image?.dispose();
    _image = image;
    _valid = true;
    _version++;
    _lastComposite = DateTime.now();
    _dirtyRegions.clear();
  }

  /// Marks regions as dirty (partial invalidation).
  void markDirty(List<ui.Rect> regions) {
    _dirtyRegions.addAll(regions);
    // Still valid, but needs partial update
  }

  /// Fully invalidates the cache.
  void invalidate(InvalidationReason reason) {
    _valid = false;
    _dirtyRegions.clear();
  }

  /// Disposes the cached image.
  void dispose() {
    _image?.dispose();
    _image = null;
    _valid = false;
    _dirtyRegions.clear();
  }
}

/// Manages per-layer GPU texture caching for efficient compositing.
///
/// Caches rendered layer images to avoid re-compositing unchanged layers.
/// Only layers with dirty regions are re-rendered, significantly reducing
/// GPU work for typical editing operations.
///
/// Features:
/// - Per-layer texture caching
/// - Partial invalidation (dirty rects only)
/// - Full invalidation on structure changes
/// - Automatic cache eviction for memory management
class LayerTextureCache {
  /// Maximum number of cached layers.
  final int maxCachedLayers;

  /// Maximum cache age before forced refresh.
  final Duration maxCacheAge;

  /// Cached textures by layer ID.
  final Map<String, LayerTexture> _textures = {};

  /// Layer order for composite output.
  List<String> _layerOrder = [];

  /// Layer visibility states.
  final Map<String, bool> _visibility = {};

  /// Layer opacity values.
  final Map<String, double> _opacity = {};

  /// Whether the composite output needs updating.
  bool _compositeInvalid = true;

  /// Dirty rect tracker integration.
  DirtyRectTracker? _dirtyTracker;

  LayerTextureCache({
    this.maxCachedLayers = 32,
    this.maxCacheAge = const Duration(minutes: 5),
  });

  /// Sets the dirty rect tracker for integration.
  void setDirtyTracker(DirtyRectTracker tracker) {
    _dirtyTracker = tracker;
  }

  /// Gets or creates a texture cache for a layer.
  LayerTexture getOrCreate(String layerId) {
    return _textures.putIfAbsent(layerId, () => LayerTexture(layerId));
  }

  /// Gets a cached texture, or null if not cached.
  LayerTexture? get(String layerId) => _textures[layerId];

  /// Updates the layer order.
  ///
  /// Invalidates composite if order changed.
  void setLayerOrder(List<String> order) {
    if (_listEquals(_layerOrder, order)) return;

    final oldOrder = _layerOrder;
    _layerOrder = List.from(order);

    // Invalidate layers that changed position
    for (var i = 0; i < order.length; i++) {
      if (i >= oldOrder.length || oldOrder[i] != order[i]) {
        _textures[order[i]]?.invalidate(InvalidationReason.reordered);
      }
    }

    _compositeInvalid = true;
  }

  /// Updates layer visibility.
  ///
  /// Invalidates composite if visibility changed.
  void setLayerVisibility(String layerId, bool visible) {
    if (_visibility[layerId] == visible) return;

    _visibility[layerId] = visible;
    _textures[layerId]?.invalidate(InvalidationReason.visibilityChanged);
    _compositeInvalid = true;
  }

  /// Updates layer opacity.
  ///
  /// Invalidates if opacity changed.
  void setLayerOpacity(String layerId, double opacity) {
    if (_opacity[layerId] == opacity) return;

    _opacity[layerId] = opacity;
    _textures[layerId]?.invalidate(InvalidationReason.opacityChanged);
    _compositeInvalid = true;
  }

  /// Marks a layer as having pixel changes.
  ///
  /// Transfers dirty regions from the tracker.
  void markLayerDirty(String layerId) {
    final texture = _textures[layerId];
    if (texture == null) return;

    final dirtyRects = _dirtyTracker?.getDirtyRects(layerId) ?? [];
    if (dirtyRects.isNotEmpty) {
      texture.markDirty(dirtyRects);
      _compositeInvalid = true;
    }
  }

  /// Called when a layer is added.
  void onLayerAdded(String layerId, int position) {
    _textures[layerId] = LayerTexture(layerId);
    _textures[layerId]!.invalidate(InvalidationReason.added);
    _compositeInvalid = true;
  }

  /// Called when a layer is deleted.
  void onLayerDeleted(String layerId) {
    _textures[layerId]?.dispose();
    _textures.remove(layerId);
    _visibility.remove(layerId);
    _opacity.remove(layerId);
    _compositeInvalid = true;
  }

  /// Gets layers that need re-rendering.
  ///
  /// Returns layer IDs with invalid or dirty caches.
  List<String> getLayersNeedingRender() {
    final result = <String>[];

    for (final layerId in _layerOrder) {
      final texture = _textures[layerId];
      final visible = _visibility[layerId] ?? true;

      if (!visible) continue;

      if (texture == null || !texture.isValid || texture.hasDirtyRegions) {
        result.add(layerId);
      } else if (texture.timeSinceComposite != null &&
          texture.timeSinceComposite! > maxCacheAge) {
        // Force refresh for stale cache
        texture.invalidate(InvalidationReason.full);
        result.add(layerId);
      }
    }

    return result;
  }

  /// Gets layers with valid cached images (for fast composite).
  List<String> getCachedLayers() {
    return _layerOrder
        .where((id) => _textures[id]?.isValid == true)
        .toList();
  }

  /// Whether the composite output needs updating.
  bool get needsComposite => _compositeInvalid;

  /// Marks composite as updated.
  void markCompositeComplete() {
    _compositeInvalid = false;
    _dirtyTracker?.clear();
  }

  /// Invalidates all caches (e.g., for full document reload).
  void invalidateAll() {
    for (final texture in _textures.values) {
      texture.invalidate(InvalidationReason.full);
    }
    _compositeInvalid = true;
  }

  /// Evicts old entries if cache is too large.
  void evictIfNeeded() {
    if (_textures.length <= maxCachedLayers) return;

    // Find entries not in current layer order
    final orphaned = _textures.keys
        .where((id) => !_layerOrder.contains(id))
        .toList();

    for (final id in orphaned) {
      _textures[id]?.dispose();
      _textures.remove(id);
    }

    // If still too large, evict oldest
    if (_textures.length > maxCachedLayers) {
      final sorted = _textures.entries.toList()
        ..sort((a, b) {
          final aTime = a.value.timeSinceComposite ?? Duration.zero;
          final bTime = b.value.timeSinceComposite ?? Duration.zero;
          return bTime.compareTo(aTime); // Oldest first
        });

      while (_textures.length > maxCachedLayers && sorted.isNotEmpty) {
        final oldest = sorted.removeAt(0);
        if (_layerOrder.contains(oldest.key)) continue; // Keep active layers
        oldest.value.dispose();
        _textures.remove(oldest.key);
      }
    }
  }

  /// Disposes all cached textures.
  void dispose() {
    for (final texture in _textures.values) {
      texture.dispose();
    }
    _textures.clear();
    _visibility.clear();
    _opacity.clear();
    _layerOrder.clear();
  }

  /// Compares two lists for equality.
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    final cached = getCachedLayers().length;
    final total = _layerOrder.length;
    final needRender = getLayersNeedingRender().length;
    return 'LayerTextureCache($cached/$total cached, $needRender need render)';
  }
}
