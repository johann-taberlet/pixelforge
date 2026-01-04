import 'dart:ui';

/// Tracks dirty (modified) regions for efficient partial repainting.
///
/// Designed to minimize GPU operations by:
/// - Merging overlapping rectangles to reduce draw calls
/// - Expanding small rects to avoid micro-updates
/// - Supporting per-layer dirty tracking
///
/// Target: < 8ms frame time with typical edit operations.
class DirtyRectTracker {
  /// Minimum size for a dirty rect (prevents micro-updates).
  static const double minDirtySize = 8.0;

  /// Merge threshold - rects closer than this are merged.
  static const double mergeThreshold = 16.0;

  /// Maximum number of rects before forcing a full repaint.
  static const int maxRects = 8;

  /// Dirty rectangles per layer, keyed by layer ID.
  final Map<String, List<Rect>> _layerDirtyRects = {};

  /// Global dirty rects (affects all layers).
  final List<Rect> _globalDirtyRects = [];

  /// Whether a full repaint is required.
  bool _forceFullRepaint = false;

  /// Canvas bounds for clamping.
  Rect _canvasBounds = Rect.zero;

  /// Set the canvas bounds.
  void setCanvasBounds(int width, int height) {
    _canvasBounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  }

  /// Mark a rectangular region as dirty for a specific layer.
  void markDirty(String layerId, Rect rect) {
    if (_forceFullRepaint) return;

    final expanded = _expandRect(rect);
    final clamped = _clampRect(expanded);
    if (clamped.isEmpty) return;

    _layerDirtyRects.putIfAbsent(layerId, () => []);
    final rects = _layerDirtyRects[layerId]!;

    rects.add(clamped);
    _mergeRects(rects);

    if (rects.length > maxRects) {
      // Too many rects - merge aggressively
      _layerDirtyRects[layerId] = [_boundingRect(rects)];
    }
  }

  /// Mark a single pixel as dirty.
  void markPixelDirty(String layerId, int x, int y) {
    markDirty(layerId, Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      1,
      1,
    ));
  }

  /// Mark a rectangular region as dirty globally (all layers).
  void markGlobalDirty(Rect rect) {
    if (_forceFullRepaint) return;

    final expanded = _expandRect(rect);
    final clamped = _clampRect(expanded);
    if (clamped.isEmpty) return;

    _globalDirtyRects.add(clamped);
    _mergeRects(_globalDirtyRects);

    if (_globalDirtyRects.length > maxRects) {
      _forceFullRepaint = true;
    }
  }

  /// Force a full repaint of all layers.
  void markFullRepaint() {
    _forceFullRepaint = true;
    _layerDirtyRects.clear();
    _globalDirtyRects.clear();
  }

  /// Get dirty rectangles for a specific layer.
  ///
  /// Returns the union of layer-specific and global dirty rects.
  List<Rect> getDirtyRects(String layerId) {
    if (_forceFullRepaint) {
      return [_canvasBounds];
    }

    final layerRects = _layerDirtyRects[layerId] ?? [];
    if (_globalDirtyRects.isEmpty) {
      return List.unmodifiable(layerRects);
    }

    // Combine layer and global rects
    final combined = [...layerRects, ..._globalDirtyRects];
    _mergeRects(combined);
    return combined;
  }

  /// Get all dirty rectangles across all layers.
  List<Rect> getAllDirtyRects() {
    if (_forceFullRepaint) {
      return [_canvasBounds];
    }

    final allRects = <Rect>[];
    for (final rects in _layerDirtyRects.values) {
      allRects.addAll(rects);
    }
    allRects.addAll(_globalDirtyRects);

    if (allRects.isEmpty) return [];

    _mergeRects(allRects);
    return allRects;
  }

  /// Get the bounding box of all dirty regions.
  Rect? getBoundingDirtyRect() {
    if (_forceFullRepaint) {
      return _canvasBounds;
    }

    final allRects = getAllDirtyRects();
    if (allRects.isEmpty) return null;

    return _boundingRect(allRects);
  }

  /// Check if any region is dirty.
  bool get hasDirtyRegions {
    if (_forceFullRepaint) return true;
    if (_globalDirtyRects.isNotEmpty) return true;
    return _layerDirtyRects.values.any((rects) => rects.isNotEmpty);
  }

  /// Check if a full repaint is required.
  bool get requiresFullRepaint => _forceFullRepaint;

  /// Clear all dirty regions after painting.
  void clear() {
    _layerDirtyRects.clear();
    _globalDirtyRects.clear();
    _forceFullRepaint = false;
  }

  /// Clear dirty regions for a specific layer.
  void clearLayer(String layerId) {
    _layerDirtyRects.remove(layerId);
  }

  /// Expand a rect to minimum size.
  Rect _expandRect(Rect rect) {
    if (rect.width >= minDirtySize && rect.height >= minDirtySize) {
      return rect;
    }

    final expandX = (minDirtySize - rect.width) / 2;
    final expandY = (minDirtySize - rect.height) / 2;

    return Rect.fromLTRB(
      rect.left - (expandX > 0 ? expandX : 0),
      rect.top - (expandY > 0 ? expandY : 0),
      rect.right + (expandX > 0 ? expandX : 0),
      rect.bottom + (expandY > 0 ? expandY : 0),
    );
  }

  /// Clamp a rect to canvas bounds.
  Rect _clampRect(Rect rect) {
    if (_canvasBounds.isEmpty) return rect;
    return rect.intersect(_canvasBounds);
  }

  /// Calculate the bounding rect of a list of rects.
  Rect _boundingRect(List<Rect> rects) {
    if (rects.isEmpty) return Rect.zero;

    var minX = rects.first.left;
    var minY = rects.first.top;
    var maxX = rects.first.right;
    var maxY = rects.first.bottom;

    for (var i = 1; i < rects.length; i++) {
      final r = rects[i];
      if (r.left < minX) minX = r.left;
      if (r.top < minY) minY = r.top;
      if (r.right > maxX) maxX = r.right;
      if (r.bottom > maxY) maxY = r.bottom;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Merge overlapping or close rectangles in place.
  void _mergeRects(List<Rect> rects) {
    if (rects.length < 2) return;

    var merged = true;
    while (merged) {
      merged = false;

      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          if (_shouldMerge(rects[i], rects[j])) {
            rects[i] = rects[i].expandToInclude(rects[j]);
            rects.removeAt(j);
            merged = true;
            break;
          }
        }
        if (merged) break;
      }
    }
  }

  /// Check if two rects should be merged.
  bool _shouldMerge(Rect a, Rect b) {
    // Merge if overlapping
    if (a.overlaps(b)) return true;

    // Merge if close together
    final expandedA = a.inflate(mergeThreshold);
    return expandedA.overlaps(b);
  }
}

/// Per-layer dirty tracking with GPU integration.
class LayerDirtyTracker {
  final DirtyRectTracker _tracker;
  final String layerId;

  /// Pixel updates pending GPU sync.
  final List<_PendingUpdate> _pendingUpdates = [];

  /// Maximum pending updates before forced flush.
  static const int maxPendingUpdates = 1000;

  LayerDirtyTracker(this._tracker, this.layerId);

  /// Mark a pixel as dirty and queue for GPU update.
  void markPixel(int x, int y, int color) {
    _tracker.markPixelDirty(layerId, x, y);
    _pendingUpdates.add(_PendingUpdate(x, y, color));

    if (_pendingUpdates.length >= maxPendingUpdates) {
      // Force a region update for efficiency
      _collapseToRegion();
    }
  }

  /// Mark a rectangular region as dirty.
  void markRegion(Rect rect) {
    _tracker.markDirty(layerId, rect);
  }

  /// Get pending pixel updates for GPU sync.
  List<({int x, int y, int color})> getPendingUpdates() {
    return _pendingUpdates
        .map((u) => (x: u.x, y: u.y, color: u.color))
        .toList();
  }

  /// Clear pending updates after GPU sync.
  void clearPending() {
    _pendingUpdates.clear();
  }

  /// Get dirty regions that need repainting.
  List<Rect> getDirtyRegions() {
    return _tracker.getDirtyRects(layerId);
  }

  /// Clear dirty state after repaint.
  void clearDirty() {
    _tracker.clearLayer(layerId);
    _pendingUpdates.clear();
  }

  void _collapseToRegion() {
    // When we have too many individual updates, collapse to bounding rect
    if (_pendingUpdates.isEmpty) return;

    var minX = _pendingUpdates.first.x;
    var minY = _pendingUpdates.first.y;
    var maxX = minX;
    var maxY = minY;

    for (final update in _pendingUpdates) {
      if (update.x < minX) minX = update.x;
      if (update.y < minY) minY = update.y;
      if (update.x > maxX) maxX = update.x;
      if (update.y > maxY) maxY = update.y;
    }

    // Clear individual updates and mark region
    _pendingUpdates.clear();
    _tracker.markDirty(
      layerId,
      Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        maxX + 1.0,
        maxY + 1.0,
      ),
    );
  }
}

class _PendingUpdate {
  final int x;
  final int y;
  final int color;

  _PendingUpdate(this.x, this.y, this.color);
}
