/// Geometry primitives and drawing algorithms for pixel art.
///
/// This library provides:
///
/// - [Point]: Integer 2D coordinates
/// - [Rect]: Integer rectangle with intersection/union operations
/// - [DrawingAlgorithms]: Bresenham line, circle, ellipse, rectangle
/// - [FloodFill]: Scanline-based flood fill for bucket tool
library;

export 'algorithms.dart';
export 'flood_fill.dart';
export 'point.dart';
export 'rect.dart';
