import 'package:flutter/foundation.dart';

import '../input/input_controller.dart';

/// State of a tool during its lifecycle.
enum ToolState {
  /// Tool is not currently in use.
  idle,

  /// Tool is actively being used (pointer is down, drawing in progress).
  active,

  /// Tool is showing a preview (e.g., hover state for shape tools).
  previewing,
}

/// Abstract base class for all drawing tools.
///
/// Tools receive input events from the [ToolController] and respond with
/// drawing operations. Each tool manages its own state and can provide
/// visual feedback during different phases of interaction.
///
/// Lifecycle:
/// 1. [onActivate] - Called when tool becomes the active tool
/// 2. [onStart] - Called on pointer down, begins a stroke/operation
/// 3. [onUpdate] - Called on pointer move during an active operation
/// 4. [onEnd] - Called on pointer up, completes the operation
/// 5. [onCancel] - Called if operation is interrupted (e.g., tool switch)
/// 6. [onDeactivate] - Called when another tool becomes active
abstract class Tool {
  /// Current state of the tool.
  ToolState _state = ToolState.idle;

  /// Gets the current state of the tool.
  ToolState get state => _state;

  /// Unique identifier for this tool (e.g., 'pencil', 'eraser').
  String get id;

  /// Human-readable display name for this tool.
  String get name;

  /// Whether the tool is currently in an active stroke/operation.
  bool get isActive => _state == ToolState.active;

  /// Whether the tool is showing a preview.
  bool get isPreviewing => _state == ToolState.previewing;

  /// Called when this tool becomes the active tool.
  ///
  /// Override to initialize tool-specific state or UI.
  @mustCallSuper
  void onActivate() {
    _state = ToolState.idle;
  }

  /// Called when another tool becomes active.
  ///
  /// Override to clean up tool-specific state or UI.
  /// If a stroke is in progress, [onCancel] is called first.
  @mustCallSuper
  void onDeactivate() {
    _state = ToolState.idle;
  }

  /// Called when a stroke/operation begins (pointer down).
  ///
  /// The [event] contains the starting point in canvas coordinates,
  /// pressure information, and pointer ID for multi-touch tracking.
  @mustCallSuper
  void onStart(CanvasInputEvent event) {
    _state = ToolState.active;
  }

  /// Called during a stroke/operation (pointer move while down).
  ///
  /// Only called when [isActive] is true. The [event] contains
  /// the current point, pressure, and other input data.
  void onUpdate(CanvasInputEvent event);

  /// Called when a stroke/operation ends normally (pointer up).
  ///
  /// This is where the tool should finalize any pending drawing
  /// operations and commit changes to the document.
  @mustCallSuper
  void onEnd(CanvasInputEvent event) {
    _state = ToolState.idle;
  }

  /// Called when a stroke/operation is cancelled.
  ///
  /// This can happen due to:
  /// - Tool switch during active stroke
  /// - Palm rejection
  /// - Pointer cancel event
  ///
  /// The tool should discard any uncommitted changes.
  @mustCallSuper
  void onCancel() {
    _state = ToolState.idle;
  }

  /// Called on hover events (pointer proximity without contact).
  ///
  /// Override to show tool previews, cursor changes, or other
  /// feedback based on pointer position.
  void onHover(CanvasInputEvent event) {
    // Default: no-op, subclasses can override for preview
  }

  /// Handle a raw input event, routing to appropriate lifecycle method.
  ///
  /// This is called by [ToolController] and handles state transitions.
  void handleInput(CanvasInputEvent event) {
    switch (event.type) {
      case InputEventType.down:
        onStart(event);
      case InputEventType.move:
        if (isActive) {
          onUpdate(event);
        }
      case InputEventType.up:
        if (isActive) {
          onEnd(event);
        }
      case InputEventType.cancel:
        if (isActive) {
          onCancel();
        }
      case InputEventType.hover:
        onHover(event);
    }
  }
}

/// Controller for managing tool registration and switching.
///
/// Provides:
/// - Tool registration by ID
/// - Active tool switching with proper lifecycle calls
/// - Input event routing to the active tool
/// - Change notification for UI updates
class ToolController extends ChangeNotifier {
  /// Registered tools by ID.
  final Map<String, Tool> _tools = {};

  /// The currently active tool.
  Tool? _activeTool;

  /// Gets the currently active tool, or null if none is active.
  Tool? get activeTool => _activeTool;

  /// Gets the ID of the currently active tool, or null if none is active.
  String? get activeToolId => _activeTool?.id;

  /// Gets all registered tool IDs.
  Iterable<String> get toolIds => _tools.keys;

  /// Gets all registered tools.
  Iterable<Tool> get tools => _tools.values;

  /// Gets a tool by ID, or null if not registered.
  Tool? getTool(String id) => _tools[id];

  /// Whether a tool with the given ID is registered.
  bool hasTool(String id) => _tools.containsKey(id);

  /// Registers a tool with the controller.
  ///
  /// If a tool with the same ID exists, it is replaced.
  /// If the replaced tool was active, the new tool becomes active.
  void register(Tool tool) {
    final wasActive = _activeTool?.id == tool.id;

    // Deactivate old tool if it was active
    if (wasActive && _activeTool != null) {
      if (_activeTool!.isActive) {
        _activeTool!.onCancel();
      }
      _activeTool!.onDeactivate();
    }

    _tools[tool.id] = tool;

    // Activate new tool if old one was active
    if (wasActive) {
      tool.onActivate();
      _activeTool = tool;
    }

    notifyListeners();
  }

  /// Unregisters a tool by ID.
  ///
  /// If the tool was active, the active tool becomes null.
  /// Returns the removed tool, or null if not found.
  Tool? unregister(String id) {
    final tool = _tools.remove(id);
    if (tool == null) return null;

    if (_activeTool?.id == id) {
      if (_activeTool!.isActive) {
        _activeTool!.onCancel();
      }
      _activeTool!.onDeactivate();
      _activeTool = null;
      notifyListeners();
    }

    return tool;
  }

  /// Sets the active tool by ID.
  ///
  /// If the tool is not registered, this does nothing.
  /// If switching during an active stroke, the current tool's
  /// [Tool.onCancel] is called before deactivation.
  void setActiveTool(String id) {
    if (!_tools.containsKey(id)) return;
    if (_activeTool?.id == id) return; // Already active

    final newTool = _tools[id]!;

    // Deactivate current tool
    if (_activeTool != null) {
      if (_activeTool!.isActive) {
        _activeTool!.onCancel();
      }
      _activeTool!.onDeactivate();
    }

    // Activate new tool
    _activeTool = newTool;
    _activeTool!.onActivate();
    notifyListeners();
  }

  /// Routes an input event to the active tool.
  ///
  /// If no tool is active, this does nothing.
  void handleInput(CanvasInputEvent event) {
    _activeTool?.handleInput(event);
  }

  /// Cancels any active stroke on the current tool.
  ///
  /// Useful when the app needs to interrupt drawing (e.g., dialog opens).
  void cancelActiveStroke() {
    if (_activeTool?.isActive == true) {
      _activeTool!.onCancel();
      notifyListeners();
    }
  }

  /// Clears all tools and deactivates the active tool.
  void clear() {
    if (_activeTool != null) {
      if (_activeTool!.isActive) {
        _activeTool!.onCancel();
      }
      _activeTool!.onDeactivate();
      _activeTool = null;
    }
    _tools.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
