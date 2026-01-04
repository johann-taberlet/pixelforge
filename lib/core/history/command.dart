/// Abstract base class for all undoable commands.
///
/// Commands encapsulate mutations that can be:
/// - Executed (apply the change)
/// - Undone (revert the change)
/// - Serialized (for persistence)
/// - Composed (for batch operations)
abstract class Command {
  /// Unique identifier for this command instance.
  final String id;

  /// Timestamp when the command was created.
  final DateTime createdAt;

  /// Human-readable description of the command.
  String get description;

  /// Command type identifier for serialization.
  String get type;

  Command({
    String? id,
    DateTime? createdAt,
  })  : id = id ?? _generateId(),
        createdAt = createdAt ?? DateTime.now();

  /// Execute the command, applying the mutation.
  ///
  /// Returns true if the command was successfully executed.
  Future<bool> execute();

  /// Undo the command, reverting the mutation.
  ///
  /// Returns true if the command was successfully undone.
  Future<bool> undo();

  /// Serialize the command to a JSON-compatible map.
  Map<String, dynamic> toJson();

  /// Deserialize a command from a JSON map.
  ///
  /// Subclasses should register their type with [CommandRegistry].
  static Command fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final factory = CommandRegistry.getFactory(type);
    if (factory == null) {
      throw ArgumentError('Unknown command type: $type');
    }
    return factory(json);
  }

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}

/// Registry for command type factories.
///
/// Enables deserialization of commands by type.
class CommandRegistry {
  static final Map<String, Command Function(Map<String, dynamic>)> _factories =
      {};

  /// Register a factory for a command type.
  static void register(
    String type,
    Command Function(Map<String, dynamic>) factory,
  ) {
    _factories[type] = factory;
  }

  /// Get the factory for a command type.
  static Command Function(Map<String, dynamic>)? getFactory(String type) {
    return _factories[type];
  }

  /// Register all built-in command types.
  static void registerBuiltInTypes() {
    register('pixel', PixelCommand.fromJson);
    register('pixels_batch', PixelBatchCommand.fromJson);
    register('layer_add', LayerAddCommand.fromJson);
    register('layer_delete', LayerDeleteCommand.fromJson);
    register('layer_reorder', LayerReorderCommand.fromJson);
    register('layer_visibility', LayerVisibilityCommand.fromJson);
    register('frame_add', FrameAddCommand.fromJson);
    register('frame_delete', FrameDeleteCommand.fromJson);
    register('composite', CompositeCommand.fromJson);
  }
}

/// A command that changes a single pixel.
class PixelCommand extends Command {
  /// Layer ID where the pixel is located.
  final int layerId;

  /// X coordinate.
  final int x;

  /// Y coordinate.
  final int y;

  /// New color value.
  final int newColor;

  /// Previous color value (for undo).
  final int oldColor;

  /// Callback to apply pixel changes.
  final Future<void> Function(int layerId, int x, int y, int color)? onApply;

  PixelCommand({
    super.id,
    super.createdAt,
    required this.layerId,
    required this.x,
    required this.y,
    required this.newColor,
    required this.oldColor,
    this.onApply,
  });

  @override
  String get description => 'Set pixel ($x, $y) on layer $layerId';

  @override
  String get type => 'pixel';

  @override
  Future<bool> execute() async {
    await onApply?.call(layerId, x, y, newColor);
    return true;
  }

  @override
  Future<bool> undo() async {
    await onApply?.call(layerId, x, y, oldColor);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'layerId': layerId,
        'x': x,
        'y': y,
        'newColor': newColor,
        'oldColor': oldColor,
      };

  factory PixelCommand.fromJson(Map<String, dynamic> json) {
    return PixelCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      layerId: json['layerId'] as int,
      x: json['x'] as int,
      y: json['y'] as int,
      newColor: json['newColor'] as int,
      oldColor: json['oldColor'] as int,
    );
  }
}

/// A command that changes multiple pixels at once.
class PixelBatchCommand extends Command {
  /// Layer ID where the pixels are located.
  final int layerId;

  /// List of pixel changes: [x, y, newColor, oldColor].
  final List<List<int>> pixels;

  /// Callback to apply pixel changes.
  final Future<void> Function(int layerId, List<List<int>> pixels)? onApply;

  PixelBatchCommand({
    super.id,
    super.createdAt,
    required this.layerId,
    required this.pixels,
    this.onApply,
  });

  @override
  String get description => 'Set ${pixels.length} pixels on layer $layerId';

  @override
  String get type => 'pixels_batch';

  @override
  Future<bool> execute() async {
    final changes = pixels.map((p) => [p[0], p[1], p[2]]).toList();
    await onApply?.call(layerId, changes);
    return true;
  }

  @override
  Future<bool> undo() async {
    final changes = pixels.map((p) => [p[0], p[1], p[3]]).toList();
    await onApply?.call(layerId, changes);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'layerId': layerId,
        'pixels': pixels,
      };

  factory PixelBatchCommand.fromJson(Map<String, dynamic> json) {
    return PixelBatchCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      layerId: json['layerId'] as int,
      pixels: (json['pixels'] as List)
          .map((p) => (p as List).cast<int>())
          .toList(),
    );
  }
}

/// A command that adds a new layer.
class LayerAddCommand extends Command {
  /// The layer ID that was/will be created.
  final int layerId;

  /// Layer name.
  final String name;

  /// Layer width.
  final int width;

  /// Layer height.
  final int height;

  /// Position in layer stack.
  final int position;

  /// Callback to add a layer.
  final Future<void> Function(int id, String name, int w, int h, int pos)?
      onAdd;

  /// Callback to remove a layer.
  final Future<void> Function(int id)? onRemove;

  LayerAddCommand({
    super.id,
    super.createdAt,
    required this.layerId,
    required this.name,
    required this.width,
    required this.height,
    required this.position,
    this.onAdd,
    this.onRemove,
  });

  @override
  String get description => 'Add layer "$name"';

  @override
  String get type => 'layer_add';

  @override
  Future<bool> execute() async {
    await onAdd?.call(layerId, name, width, height, position);
    return true;
  }

  @override
  Future<bool> undo() async {
    await onRemove?.call(layerId);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'layerId': layerId,
        'name': name,
        'width': width,
        'height': height,
        'position': position,
      };

  factory LayerAddCommand.fromJson(Map<String, dynamic> json) {
    return LayerAddCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      layerId: json['layerId'] as int,
      name: json['name'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      position: json['position'] as int,
    );
  }
}

/// A command that deletes a layer.
class LayerDeleteCommand extends Command {
  /// The layer ID to delete.
  final int layerId;

  /// Layer name (for recreation).
  final String name;

  /// Layer width.
  final int width;

  /// Layer height.
  final int height;

  /// Position in layer stack.
  final int position;

  /// Serialized layer data (for undo).
  final String? layerData;

  /// Callback to add a layer.
  final Future<void> Function(int id, String name, int w, int h, int pos,
      String? data)? onAdd;

  /// Callback to remove a layer.
  final Future<void> Function(int id)? onRemove;

  LayerDeleteCommand({
    super.id,
    super.createdAt,
    required this.layerId,
    required this.name,
    required this.width,
    required this.height,
    required this.position,
    this.layerData,
    this.onAdd,
    this.onRemove,
  });

  @override
  String get description => 'Delete layer "$name"';

  @override
  String get type => 'layer_delete';

  @override
  Future<bool> execute() async {
    await onRemove?.call(layerId);
    return true;
  }

  @override
  Future<bool> undo() async {
    await onAdd?.call(layerId, name, width, height, position, layerData);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'layerId': layerId,
        'name': name,
        'width': width,
        'height': height,
        'position': position,
        'layerData': layerData,
      };

  factory LayerDeleteCommand.fromJson(Map<String, dynamic> json) {
    return LayerDeleteCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      layerId: json['layerId'] as int,
      name: json['name'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      position: json['position'] as int,
      layerData: json['layerData'] as String?,
    );
  }
}

/// A command that reorders layers.
class LayerReorderCommand extends Command {
  /// Old order of layer IDs.
  final List<int> oldOrder;

  /// New order of layer IDs.
  final List<int> newOrder;

  /// Callback to apply layer order.
  final Future<void> Function(List<int> order)? onApply;

  LayerReorderCommand({
    super.id,
    super.createdAt,
    required this.oldOrder,
    required this.newOrder,
    this.onApply,
  });

  @override
  String get description => 'Reorder layers';

  @override
  String get type => 'layer_reorder';

  @override
  Future<bool> execute() async {
    await onApply?.call(newOrder);
    return true;
  }

  @override
  Future<bool> undo() async {
    await onApply?.call(oldOrder);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'oldOrder': oldOrder,
        'newOrder': newOrder,
      };

  factory LayerReorderCommand.fromJson(Map<String, dynamic> json) {
    return LayerReorderCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      oldOrder: (json['oldOrder'] as List).cast<int>(),
      newOrder: (json['newOrder'] as List).cast<int>(),
    );
  }
}

/// A command that changes layer visibility.
class LayerVisibilityCommand extends Command {
  /// Layer ID.
  final int layerId;

  /// Old visibility state.
  final bool oldVisible;

  /// New visibility state.
  final bool newVisible;

  /// Callback to apply visibility.
  final Future<void> Function(int layerId, bool visible)? onApply;

  LayerVisibilityCommand({
    super.id,
    super.createdAt,
    required this.layerId,
    required this.oldVisible,
    required this.newVisible,
    this.onApply,
  });

  @override
  String get description =>
      '${newVisible ? 'Show' : 'Hide'} layer $layerId';

  @override
  String get type => 'layer_visibility';

  @override
  Future<bool> execute() async {
    await onApply?.call(layerId, newVisible);
    return true;
  }

  @override
  Future<bool> undo() async {
    await onApply?.call(layerId, oldVisible);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'layerId': layerId,
        'oldVisible': oldVisible,
        'newVisible': newVisible,
      };

  factory LayerVisibilityCommand.fromJson(Map<String, dynamic> json) {
    return LayerVisibilityCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      layerId: json['layerId'] as int,
      oldVisible: json['oldVisible'] as bool,
      newVisible: json['newVisible'] as bool,
    );
  }
}

/// A command that adds a new frame.
class FrameAddCommand extends Command {
  /// Frame ID.
  final int frameId;

  /// Frame position in timeline.
  final int position;

  /// Frame duration in milliseconds.
  final int duration;

  /// Callback to add a frame.
  final Future<void> Function(int id, int pos, int dur)? onAdd;

  /// Callback to remove a frame.
  final Future<void> Function(int id)? onRemove;

  FrameAddCommand({
    super.id,
    super.createdAt,
    required this.frameId,
    required this.position,
    this.duration = 100,
    this.onAdd,
    this.onRemove,
  });

  @override
  String get description => 'Add frame at position $position';

  @override
  String get type => 'frame_add';

  @override
  Future<bool> execute() async {
    await onAdd?.call(frameId, position, duration);
    return true;
  }

  @override
  Future<bool> undo() async {
    await onRemove?.call(frameId);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'frameId': frameId,
        'position': position,
        'duration': duration,
      };

  factory FrameAddCommand.fromJson(Map<String, dynamic> json) {
    return FrameAddCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      frameId: json['frameId'] as int,
      position: json['position'] as int,
      duration: json['duration'] as int? ?? 100,
    );
  }
}

/// A command that deletes a frame.
class FrameDeleteCommand extends Command {
  /// Frame ID.
  final int frameId;

  /// Frame position in timeline.
  final int position;

  /// Frame duration in milliseconds.
  final int duration;

  /// Serialized frame data (for undo).
  final String? frameData;

  /// Callback to add a frame.
  final Future<void> Function(int id, int pos, int dur, String? data)? onAdd;

  /// Callback to remove a frame.
  final Future<void> Function(int id)? onRemove;

  FrameDeleteCommand({
    super.id,
    super.createdAt,
    required this.frameId,
    required this.position,
    required this.duration,
    this.frameData,
    this.onAdd,
    this.onRemove,
  });

  @override
  String get description => 'Delete frame at position $position';

  @override
  String get type => 'frame_delete';

  @override
  Future<bool> execute() async {
    await onRemove?.call(frameId);
    return true;
  }

  @override
  Future<bool> undo() async {
    await onAdd?.call(frameId, position, duration, frameData);
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'frameId': frameId,
        'position': position,
        'duration': duration,
        'frameData': frameData,
      };

  factory FrameDeleteCommand.fromJson(Map<String, dynamic> json) {
    return FrameDeleteCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      frameId: json['frameId'] as int,
      position: json['position'] as int,
      duration: json['duration'] as int,
      frameData: json['frameData'] as String?,
    );
  }
}

/// A command that composes multiple commands into a single undoable unit.
class CompositeCommand extends Command {
  /// The child commands.
  final List<Command> commands;

  /// Description override.
  final String? _description;

  CompositeCommand({
    super.id,
    super.createdAt,
    required this.commands,
    String? description,
  }) : _description = description;

  @override
  String get description =>
      _description ?? 'Batch of ${commands.length} operations';

  @override
  String get type => 'composite';

  @override
  Future<bool> execute() async {
    for (final cmd in commands) {
      final success = await cmd.execute();
      if (!success) return false;
    }
    return true;
  }

  @override
  Future<bool> undo() async {
    // Undo in reverse order
    for (final cmd in commands.reversed) {
      final success = await cmd.undo();
      if (!success) return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'description': _description,
        'commands': commands.map((c) => c.toJson()).toList(),
      };

  factory CompositeCommand.fromJson(Map<String, dynamic> json) {
    return CompositeCommand(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
      commands: (json['commands'] as List)
          .map((c) => Command.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
