import 'cel.dart';
import 'frame.dart';
import 'layer.dart';
import 'pixel_buffer.dart';

/// A sprite document containing layers, frames, and cels.
///
/// The sprite is the main container for a pixel art document.
/// It manages the canvas dimensions, layers (vertical axis of timeline),
/// frames (horizontal axis of timeline), and cels (layer+frame intersections).
class Sprite {
  /// Canvas width in pixels.
  final int width;

  /// Canvas height in pixels.
  final int height;

  /// Ordered list of layers (bottom to top).
  final List<Layer> _layers = [];

  /// Ordered list of frames (left to right in timeline).
  final List<Frame> _frames = [];

  /// Cels indexed by "layerId:frameId" key.
  final Map<String, Cel> _cels = {};

  /// Default frame duration in milliseconds.
  int defaultFrameDurationMs;

  /// Creates a new sprite with the given dimensions.
  ///
  /// Creates one default layer and one default frame.
  Sprite({
    required this.width,
    required this.height,
    this.defaultFrameDurationMs = 100,
  }) {
    // Create a default layer and frame
    addLayer(name: 'Layer 1');
    addFrame();
  }

  /// Creates an empty sprite without default layer/frame.
  Sprite.empty({
    required this.width,
    required this.height,
    this.defaultFrameDurationMs = 100,
  });

  // --- Layers ---

  /// Read-only list of layers (bottom to top order).
  List<Layer> get layers => List.unmodifiable(_layers);

  /// Number of layers.
  int get layerCount => _layers.length;

  /// Gets a layer by index.
  Layer getLayer(int index) => _layers[index];

  /// Gets a layer by ID, or null if not found.
  Layer? getLayerById(int id) {
    try {
      return _layers.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Gets the index of a layer by ID, or -1 if not found.
  int getLayerIndex(int id) => _layers.indexWhere((l) => l.id == id);

  /// Adds a new layer at the top of the stack.
  Layer addLayer({String? name}) {
    final id = _generateLayerId();
    final layer = Layer(
      id: id,
      name: name ?? 'Layer ${_layers.length + 1}',
      width: width,
      height: height,
    );
    _layers.add(layer);
    return layer;
  }

  /// Inserts a layer at the given index.
  void insertLayer(int index, Layer layer) {
    _layers.insert(index, layer);
  }

  /// Removes a layer and all its cels.
  bool removeLayer(int id) {
    final index = getLayerIndex(id);
    if (index == -1) return false;

    _layers.removeAt(index);

    // Remove all cels for this layer
    final layerIdStr = id.toString();
    _cels.removeWhere((key, cel) => cel.layerId == layerIdStr);
    return true;
  }

  /// Moves a layer from one index to another.
  void moveLayer(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    final layer = _layers.removeAt(fromIndex);
    _layers.insert(toIndex > fromIndex ? toIndex - 1 : toIndex, layer);
  }

  // --- Frames ---

  /// Read-only list of frames.
  List<Frame> get frames => List.unmodifiable(_frames);

  /// Number of frames.
  int get frameCount => _frames.length;

  /// Gets a frame by index.
  Frame getFrame(int index) => _frames[index];

  /// Gets a frame by ID, or null if not found.
  Frame? getFrameById(String id) {
    try {
      return _frames.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Gets the index of a frame by ID, or -1 if not found.
  int getFrameIndex(String id) => _frames.indexWhere((f) => f.id == id);

  /// Adds a new frame at the end.
  Frame addFrame({int? durationMs}) {
    final id = _generateFrameId();
    final frame = Frame(
      id: id,
      durationMs: durationMs ?? defaultFrameDurationMs,
    );
    _frames.add(frame);
    return frame;
  }

  /// Inserts a frame at the given index.
  void insertFrame(int index, Frame frame) {
    _frames.insert(index, frame);
  }

  /// Removes a frame and all its cels.
  bool removeFrame(String id) {
    final index = getFrameIndex(id);
    if (index == -1) return false;

    _frames.removeAt(index);

    // Remove all cels for this frame
    _cels.removeWhere((key, cel) => cel.frameId == id);
    return true;
  }

  /// Moves a frame from one index to another.
  void moveFrame(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    final frame = _frames.removeAt(fromIndex);
    _frames.insert(toIndex > fromIndex ? toIndex - 1 : toIndex, frame);
  }

  /// Total duration of the animation in milliseconds.
  int get totalDurationMs {
    return _frames.fold(0, (sum, f) => sum + f.durationMs);
  }

  // --- Cels ---

  /// Gets a cel at the layer/frame intersection.
  Cel? getCel(String layerId, String frameId) {
    return _cels['$layerId:$frameId'];
  }

  /// Gets a cel by layer and frame indices.
  Cel? getCelAt(int layerIndex, int frameIndex) {
    if (layerIndex < 0 || layerIndex >= _layers.length) return null;
    if (frameIndex < 0 || frameIndex >= _frames.length) return null;
    return getCel(_layers[layerIndex].id.toString(), _frames[frameIndex].id);
  }

  /// Sets a cel at the layer/frame intersection.
  void setCel(Cel cel) {
    _cels[cel.key] = cel;
  }

  /// Creates and sets a new cel with a fresh pixel buffer.
  Cel createCel(String layerId, String frameId) {
    final cel = Cel(
      layerId: layerId,
      frameId: frameId,
      buffer: PixelBuffer(width, height),
    );
    setCel(cel);
    return cel;
  }

  /// Removes a cel at the layer/frame intersection.
  Cel? removeCel(String layerId, String frameId) {
    return _cels.remove('$layerId:$frameId');
  }

  /// Gets all cels for a specific layer.
  List<Cel> getCelsForLayer(String layerId) {
    return _cels.values.where((c) => c.layerId == layerId).toList();
  }

  /// Gets all cels for a specific frame.
  List<Cel> getCelsForFrame(String frameId) {
    return _cels.values.where((c) => c.frameId == frameId).toList();
  }

  /// All cels in the sprite.
  Iterable<Cel> get cels => _cels.values;

  /// Number of cels.
  int get celCount => _cels.length;

  // --- Utilities ---

  int _idCounter = 0;

  int _generateLayerId() {
    return _idCounter++;
  }

  String _generateFrameId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
  }

  @override
  String toString() =>
      'Sprite(${width}x$height, ${_layers.length} layers, ${_frames.length} frames, ${_cels.length} cels)';
}
