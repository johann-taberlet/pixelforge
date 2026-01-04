import 'dart:async';
import 'dart:typed_data';

import 'command.dart';

/// Callback for creating a checkpoint snapshot.
typedef CheckpointCreator = Future<Checkpoint> Function();

/// Callback for restoring from a checkpoint.
typedef CheckpointRestorer = Future<void> Function(Checkpoint checkpoint);

/// A checkpoint snapshot of the document state.
///
/// Checkpoints store complete state that can be restored quickly,
/// avoiding the need to replay many commands.
class Checkpoint {
  /// Unique identifier for this checkpoint.
  final String id;

  /// Timestamp when the checkpoint was created.
  final DateTime createdAt;

  /// Command ID after which this checkpoint was created.
  ///
  /// All commands up to and including this ID are reflected in the checkpoint.
  final String afterCommandId;

  /// Position in the command history (for faster lookup).
  final int historyPosition;

  /// Serialized document state (format depends on implementation).
  final Uint8List? data;

  /// GPU texture snapshot IDs (for texture-based checkpoints).
  final Map<int, int>? textureSnapshots;

  Checkpoint({
    String? id,
    DateTime? createdAt,
    required this.afterCommandId,
    required this.historyPosition,
    this.data,
    this.textureSnapshots,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        createdAt = createdAt ?? DateTime.now();

  /// Estimated memory size of this checkpoint in bytes.
  int get estimatedSize {
    var size = 0;
    if (data != null) size += data!.length;
    if (textureSnapshots != null) {
      // Rough estimate: each texture snapshot is ~width*height*4 bytes
      // This should be provided by the actual implementation
      size += textureSnapshots!.length * 1024; // Placeholder
    }
    return size;
  }
}

/// Configuration for the command history.
class CommandHistoryConfig {
  /// Number of commands between automatic checkpoints.
  final int checkpointInterval;

  /// Time between automatic checkpoints.
  final Duration checkpointTimeInterval;

  /// Maximum number of checkpoints to keep.
  final int maxCheckpoints;

  /// Maximum number of commands to keep after the oldest checkpoint.
  ///
  /// Commands older than this are pruned when they're no longer needed
  /// for undo (i.e., after checkpoint creation).
  final int maxCommandsAfterCheckpoint;

  /// Whether to create checkpoints automatically.
  final bool autoCheckpoint;

  const CommandHistoryConfig({
    this.checkpointInterval = 20,
    this.checkpointTimeInterval = const Duration(seconds: 30),
    this.maxCheckpoints = 3,
    this.maxCommandsAfterCheckpoint = 50,
    this.autoCheckpoint = true,
  });
}

/// Manages undo/redo with a hybrid checkpoint system.
///
/// Features:
/// - Undo/redo stacks with O(1) navigation
/// - Automatic checkpoints every N operations or T seconds
/// - Checkpoint pruning to limit memory usage
/// - Fast undo/redo by replaying from nearest checkpoint
///
/// Target: < 50ms undo/redo operations.
class CommandHistory {
  /// Configuration for checkpoint behavior.
  final CommandHistoryConfig config;

  /// Callback to create a checkpoint.
  final CheckpointCreator? onCreateCheckpoint;

  /// Callback to restore from a checkpoint.
  final CheckpointRestorer? onRestoreCheckpoint;

  /// All executed commands in order.
  final List<Command> _commands = [];

  /// Current position in command history.
  ///
  /// Points to the last executed command index + 1.
  /// Commands from 0 to _position-1 are executed.
  /// Commands from _position to end are on the redo stack.
  int _position = 0;

  /// Checkpoints, ordered by historyPosition.
  final List<Checkpoint> _checkpoints = [];

  /// Commands since last checkpoint.
  int _commandsSinceCheckpoint = 0;

  /// Timer for time-based checkpointing.
  Timer? _checkpointTimer;

  /// Last checkpoint creation time.
  DateTime? _lastCheckpointTime;

  /// Whether the history has been modified since last save.
  bool _isDirty = false;

  CommandHistory({
    this.config = const CommandHistoryConfig(),
    this.onCreateCheckpoint,
    this.onRestoreCheckpoint,
  }) {
    _startCheckpointTimer();
  }

  /// Whether there are commands that can be undone.
  bool get canUndo => _position > 0;

  /// Whether there are commands that can be redone.
  bool get canRedo => _position < _commands.length;

  /// Number of commands that can be undone.
  int get undoCount => _position;

  /// Number of commands that can be redone.
  int get redoCount => _commands.length - _position;

  /// Total number of commands in history.
  int get totalCommands => _commands.length;

  /// Number of checkpoints.
  int get checkpointCount => _checkpoints.length;

  /// Whether the history has unsaved changes.
  bool get isDirty => _isDirty;

  /// Description of the command that would be undone.
  String? get undoDescription =>
      canUndo ? _commands[_position - 1].description : null;

  /// Description of the command that would be redone.
  String? get redoDescription =>
      canRedo ? _commands[_position].description : null;

  /// Execute a command and add it to history.
  Future<bool> execute(Command command) async {
    // Execute the command
    final success = await command.execute();
    if (!success) return false;

    // Clear any redo history
    if (_position < _commands.length) {
      _commands.removeRange(_position, _commands.length);
      // Remove checkpoints that are now invalid
      _checkpoints.removeWhere((c) => c.historyPosition >= _position);
    }

    // Add to history
    _commands.add(command);
    _position++;
    _commandsSinceCheckpoint++;
    _isDirty = true;

    // Check if we should create a checkpoint
    await _maybeCreateCheckpoint();

    return true;
  }

  /// Undo the last command.
  ///
  /// Returns the undone command, or null if nothing to undo.
  Future<Command?> undo() async {
    if (!canUndo) return null;

    final command = _commands[_position - 1];
    final success = await command.undo();

    if (success) {
      _position--;
      _isDirty = true;
    }

    return success ? command : null;
  }

  /// Redo the next command.
  ///
  /// Returns the redone command, or null if nothing to redo.
  Future<Command?> redo() async {
    if (!canRedo) return null;

    final command = _commands[_position];
    final success = await command.execute();

    if (success) {
      _position++;
      _isDirty = true;
    }

    return success ? command : null;
  }

  /// Undo multiple commands at once.
  ///
  /// For large jumps, uses the nearest checkpoint for efficiency.
  Future<int> undoMultiple(int count) async {
    if (count <= 0) return 0;
    count = count.clamp(0, _position);

    final targetPosition = _position - count;

    // Find nearest checkpoint at or before target
    final checkpoint = _findNearestCheckpoint(targetPosition);

    if (checkpoint != null && targetPosition - checkpoint.historyPosition < count ~/ 2) {
      // Faster to restore checkpoint and replay forward
      await _restoreToCheckpoint(checkpoint);

      // Replay commands from checkpoint to target
      for (var i = checkpoint.historyPosition; i < targetPosition; i++) {
        await _commands[i].execute();
      }
      _position = targetPosition;
    } else {
      // Undo commands one by one
      var undone = 0;
      while (undone < count && canUndo) {
        final result = await undo();
        if (result != null) undone++;
      }
      return undone;
    }

    _isDirty = true;
    return count;
  }

  /// Redo multiple commands at once.
  Future<int> redoMultiple(int count) async {
    if (count <= 0) return 0;
    count = count.clamp(0, redoCount);

    var redone = 0;
    while (redone < count && canRedo) {
      final result = await redo();
      if (result != null) redone++;
    }

    return redone;
  }

  /// Jump to a specific position in history.
  ///
  /// Uses checkpoints for efficiency when possible.
  Future<void> jumpTo(int position) async {
    position = position.clamp(0, _commands.length);

    if (position == _position) return;

    if (position < _position) {
      await undoMultiple(_position - position);
    } else {
      await redoMultiple(position - _position);
    }
  }

  /// Create a checkpoint at the current position.
  Future<Checkpoint?> createCheckpoint() async {
    if (onCreateCheckpoint == null) return null;
    if (_position == 0) return null;

    final lastCommand = _commands[_position - 1];
    final checkpoint = await onCreateCheckpoint!();

    // Update checkpoint metadata
    final fullCheckpoint = Checkpoint(
      id: checkpoint.id,
      createdAt: checkpoint.createdAt,
      afterCommandId: lastCommand.id,
      historyPosition: _position,
      data: checkpoint.data,
      textureSnapshots: checkpoint.textureSnapshots,
    );

    _checkpoints.add(fullCheckpoint);
    _commandsSinceCheckpoint = 0;
    _lastCheckpointTime = DateTime.now();

    // Prune old checkpoints if needed
    _pruneCheckpoints();
    _pruneOldCommands();

    return fullCheckpoint;
  }

  /// Clear all history.
  void clear() {
    _commands.clear();
    _checkpoints.clear();
    _position = 0;
    _commandsSinceCheckpoint = 0;
    _isDirty = false;
  }

  /// Mark the history as saved (clears dirty flag).
  void markSaved() {
    _isDirty = false;
  }

  /// Dispose of resources.
  void dispose() {
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
  }

  /// Find the nearest checkpoint at or before the given position.
  Checkpoint? _findNearestCheckpoint(int position) {
    Checkpoint? nearest;
    for (final checkpoint in _checkpoints) {
      if (checkpoint.historyPosition <= position) {
        if (nearest == null ||
            checkpoint.historyPosition > nearest.historyPosition) {
          nearest = checkpoint;
        }
      }
    }
    return nearest;
  }

  /// Restore to a checkpoint state.
  Future<void> _restoreToCheckpoint(Checkpoint checkpoint) async {
    if (onRestoreCheckpoint == null) return;
    await onRestoreCheckpoint!(checkpoint);
    _position = checkpoint.historyPosition;
  }

  /// Check if we should create a checkpoint automatically.
  Future<void> _maybeCreateCheckpoint() async {
    if (!config.autoCheckpoint) return;
    if (onCreateCheckpoint == null) return;

    final shouldCheckpoint = _commandsSinceCheckpoint >= config.checkpointInterval;

    if (shouldCheckpoint) {
      await createCheckpoint();
    }
  }

  /// Prune checkpoints beyond the maximum.
  void _pruneCheckpoints() {
    while (_checkpoints.length > config.maxCheckpoints) {
      // Remove oldest checkpoint
      _checkpoints.removeAt(0);
    }
  }

  /// Prune commands that are no longer needed.
  ///
  /// Keeps commands from the oldest checkpoint forward.
  void _pruneOldCommands() {
    if (_checkpoints.isEmpty) return;

    final oldestCheckpointPosition = _checkpoints.first.historyPosition;

    // Don't prune if we might need to undo beyond the checkpoint
    if (oldestCheckpointPosition <= config.maxCommandsAfterCheckpoint) return;

    // Calculate how many commands to remove
    final pruneCount = oldestCheckpointPosition - config.maxCommandsAfterCheckpoint;
    if (pruneCount <= 0) return;

    // Remove old commands
    _commands.removeRange(0, pruneCount);

    // Adjust position and checkpoint positions
    _position -= pruneCount;
    for (var i = 0; i < _checkpoints.length; i++) {
      final cp = _checkpoints[i];
      _checkpoints[i] = Checkpoint(
        id: cp.id,
        createdAt: cp.createdAt,
        afterCommandId: cp.afterCommandId,
        historyPosition: cp.historyPosition - pruneCount,
        data: cp.data,
        textureSnapshots: cp.textureSnapshots,
      );
    }
  }

  /// Start the timer for time-based checkpointing.
  void _startCheckpointTimer() {
    if (!config.autoCheckpoint) return;

    _checkpointTimer?.cancel();
    _checkpointTimer = Timer.periodic(
      const Duration(seconds: 5), // Check every 5 seconds
      (_) => _checkTimeBasedCheckpoint(),
    );
  }

  /// Check if we should create a time-based checkpoint.
  void _checkTimeBasedCheckpoint() {
    if (!config.autoCheckpoint) return;
    if (onCreateCheckpoint == null) return;
    if (_commandsSinceCheckpoint == 0) return;

    final now = DateTime.now();
    final lastTime = _lastCheckpointTime ?? _commands.first.createdAt;
    final elapsed = now.difference(lastTime);

    if (elapsed >= config.checkpointTimeInterval) {
      createCheckpoint();
    }
  }

  /// Get history statistics for debugging.
  Map<String, dynamic> getStats() {
    return {
      'totalCommands': _commands.length,
      'position': _position,
      'undoCount': undoCount,
      'redoCount': redoCount,
      'checkpointCount': _checkpoints.length,
      'commandsSinceCheckpoint': _commandsSinceCheckpoint,
      'isDirty': _isDirty,
    };
  }
}
