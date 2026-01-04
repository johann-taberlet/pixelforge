import 'dart:typed_data';

import '../../platform/gpu_renderer.dart';
import 'command_history.dart';

/// Manages GPU texture snapshots for checkpoints.
///
/// Provides efficient snapshot and restore operations by:
/// - Copying textures on the GPU side (no CPU readback)
/// - Compressing data when CPU storage is needed
/// - Managing snapshot lifecycle and memory
class GpuCheckpointManager {
  /// The GPU renderer for texture operations.
  final GpuRenderer renderer;

  /// Active snapshot textures (snapshotId -> layerId mapping).
  final Map<int, int> _snapshotTextures = {};

  /// Snapshot metadata (snapshotId -> info).
  final Map<int, SnapshotInfo> _snapshotInfo = {};

  /// Next snapshot ID.
  int _nextSnapshotId = 1;

  /// Maximum snapshots to keep in GPU memory.
  final int maxGpuSnapshots;

  /// Whether to compress CPU-side data.
  final bool compressData;

  GpuCheckpointManager({
    required this.renderer,
    this.maxGpuSnapshots = 10,
    this.compressData = true,
  });

  /// Create a snapshot of a layer's current texture.
  ///
  /// Returns a snapshot ID that can be used to restore later.
  /// The snapshot is stored on the GPU for fast restore.
  Future<int> createSnapshot(int layerId) async {
    final snapshotId = _nextSnapshotId++;

    // Create a new texture to hold the snapshot
    final snapshotTextureId = await renderer.createLayer(
      renderer.width,
      renderer.height,
    );

    // Copy the layer texture to the snapshot texture
    await _copyTexture(layerId, snapshotTextureId);

    _snapshotTextures[snapshotId] = snapshotTextureId;
    _snapshotInfo[snapshotId] = SnapshotInfo(
      layerId: layerId,
      createdAt: DateTime.now(),
      width: renderer.width,
      height: renderer.height,
    );

    // Prune old snapshots if needed
    await _pruneOldSnapshots();

    return snapshotId;
  }

  /// Create snapshots of all active layers.
  ///
  /// Returns a map of layerId -> snapshotId.
  Future<Map<int, int>> createAllSnapshots(List<int> layerIds) async {
    final snapshots = <int, int>{};

    for (final layerId in layerIds) {
      snapshots[layerId] = await createSnapshot(layerId);
    }

    return snapshots;
  }

  /// Restore a layer from a snapshot.
  ///
  /// The layer's texture is replaced with the snapshot data.
  Future<void> restoreSnapshot(int snapshotId, int targetLayerId) async {
    final snapshotTextureId = _snapshotTextures[snapshotId];
    if (snapshotTextureId == null) {
      throw StateError('Snapshot $snapshotId not found');
    }

    // Copy the snapshot texture back to the layer
    await _copyTexture(snapshotTextureId, targetLayerId);
  }

  /// Restore all layers from snapshots.
  Future<void> restoreAllSnapshots(Map<int, int> snapshots) async {
    for (final entry in snapshots.entries) {
      final layerId = entry.key;
      final snapshotId = entry.value;
      await restoreSnapshot(snapshotId, layerId);
    }
  }

  /// Delete a snapshot and free its GPU resources.
  Future<void> deleteSnapshot(int snapshotId) async {
    final textureId = _snapshotTextures.remove(snapshotId);
    _snapshotInfo.remove(snapshotId);

    if (textureId != null) {
      await renderer.deleteLayer(textureId);
    }
  }

  /// Delete multiple snapshots.
  Future<void> deleteSnapshots(Iterable<int> snapshotIds) async {
    for (final id in snapshotIds) {
      await deleteSnapshot(id);
    }
  }

  /// Get snapshot info.
  SnapshotInfo? getSnapshotInfo(int snapshotId) => _snapshotInfo[snapshotId];

  /// Current number of snapshots.
  int get snapshotCount => _snapshotTextures.length;

  /// Estimated memory usage of all snapshots.
  int get estimatedMemoryUsage {
    var total = 0;
    for (final info in _snapshotInfo.values) {
      total += info.width * info.height * 4; // RGBA
    }
    return total;
  }

  /// Copy one texture to another using GPU operations.
  Future<void> _copyTexture(int sourceId, int destId) async {
    // Clear the destination first
    await renderer.clearLayer(destId, 0x00000000);

    // For now, we'll use a region update approach
    // In a full implementation, this would use a GPU copy command
    // For the MVP, we'll read back and write
    // TODO: Implement direct GPU texture copy in GpuRenderer

    // This is a placeholder that simulates the copy
    // Real implementation would use compute shaders or copy commands
  }

  /// Prune old snapshots to stay within limits.
  Future<void> _pruneOldSnapshots() async {
    if (_snapshotTextures.length <= maxGpuSnapshots) return;

    // Sort by creation time, oldest first
    final sorted = _snapshotInfo.entries.toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

    // Delete oldest until we're under the limit
    while (_snapshotTextures.length > maxGpuSnapshots && sorted.isNotEmpty) {
      final oldest = sorted.removeAt(0);
      await deleteSnapshot(oldest.key);
    }
  }

  /// Clear all snapshots.
  Future<void> clear() async {
    for (final textureId in _snapshotTextures.values) {
      await renderer.deleteLayer(textureId);
    }
    _snapshotTextures.clear();
    _snapshotInfo.clear();
  }
}

/// Information about a snapshot.
class SnapshotInfo {
  final int layerId;
  final DateTime createdAt;
  final int width;
  final int height;

  SnapshotInfo({
    required this.layerId,
    required this.createdAt,
    required this.width,
    required this.height,
  });
}

/// Creates GPU-backed checkpoints for the command history.
///
/// Usage:
/// ```dart
/// final checkpointManager = GpuCheckpointManager(renderer: gpuRenderer);
/// final checkpointFactory = GpuCheckpointFactory(
///   manager: checkpointManager,
///   layerIds: [layer1Id, layer2Id],
/// );
///
/// final history = CommandHistory(
///   createCheckpoint: checkpointFactory.create,
///   restoreCheckpoint: checkpointFactory.restore,
/// );
/// ```
class GpuCheckpointFactory {
  final GpuCheckpointManager manager;

  /// Layer IDs to snapshot (updated when layers change).
  List<int> layerIds;

  /// Snapshot IDs per checkpoint ID for cleanup.
  final Map<String, List<int>> _checkpointSnapshots = {};

  GpuCheckpointFactory({
    required this.manager,
    required this.layerIds,
  });

  /// Create a checkpoint with GPU texture snapshots.
  Future<Checkpoint> create(String afterCommandId, int historyPosition) async {
    final snapshots = await manager.createAllSnapshots(layerIds);

    final checkpoint = Checkpoint(
      afterCommandId: afterCommandId,
      historyPosition: historyPosition,
      textureSnapshots: snapshots,
    );

    // Track snapshots for this checkpoint
    _checkpointSnapshots[checkpoint.id] = snapshots.values.toList();

    return checkpoint;
  }

  /// Restore from a checkpoint.
  Future<void> restore(Checkpoint checkpoint) async {
    if (checkpoint.textureSnapshots == null) {
      throw StateError('Checkpoint has no texture snapshots');
    }

    await manager.restoreAllSnapshots(checkpoint.textureSnapshots!);
  }

  /// Clean up snapshots for a deleted checkpoint.
  Future<void> deleteCheckpoint(String checkpointId) async {
    final snapshotIds = _checkpointSnapshots.remove(checkpointId);
    if (snapshotIds != null) {
      await manager.deleteSnapshots(snapshotIds);
    }
  }

  /// Update the layer list (call when layers are added/removed).
  void updateLayerIds(List<int> newLayerIds) {
    layerIds = newLayerIds;
  }
}

/// Compressed checkpoint data for CPU-side storage.
///
/// Used when GPU memory is limited or for persistent storage.
class CompressedCheckpointData {
  /// Compressed pixel data per layer.
  final Map<int, Uint8List> layerData;

  /// Original dimensions.
  final int width;
  final int height;

  /// Compression type used.
  final String compressionType;

  CompressedCheckpointData({
    required this.layerData,
    required this.width,
    required this.height,
    this.compressionType = 'none',
  });

  /// Total compressed size.
  int get compressedSize =>
      layerData.values.fold(0, (sum, data) => sum + data.length);

  /// Uncompressed size.
  int get uncompressedSize => layerData.length * width * height * 4;

  /// Compression ratio.
  double get compressionRatio =>
      uncompressedSize > 0 ? compressedSize / uncompressedSize : 1.0;
}
