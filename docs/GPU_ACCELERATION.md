# GPU Acceleration Roadmap

## Current Architecture

PixelForge uses a **Cel-based document model**:

```
Sprite
├── Layers[] (metadata: id, name, opacity, blendMode, visible, locked)
├── Frames[] (metadata: id, durationMs)
└── Cels{} (pixel data: layerId + frameId → PixelBuffer)
```

**Current rendering** (`CompositeCanvas`):
- CPU-based pixel-by-pixel drawing
- Iterates through layers, fetches Cel for current frame
- Draws each pixel as a 1x1 rect with blend mode and opacity
- Works but slow for large canvases or many layers

**Target**: < 4ms composite time for 8 layers at 1024x1024

---

## GPU Acceleration Strategy

### Core Concept

Instead of drawing pixel-by-pixel on CPU:
1. Upload each Cel's PixelBuffer to a GPU texture
2. Composite textures using GPU shaders (blend modes, opacity)
3. Display result via Flutter's rendering pipeline

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Widget                        │
│                   (CompositeCanvas)                      │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│                   GpuCompositor                          │
│  - Manages texture cache per Cel                         │
│  - Tracks dirty regions                                  │
│  - Orchestrates render passes                            │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│               Platform Renderer (Abstract)               │
│  - createTexture(width, height) → TextureId             │
│  - updateTexture(id, region, pixels)                    │
│  - composite(layers[], blendModes[], opacities[])       │
│  - toImage() → ui.Image                                 │
└─────────────────────────┬───────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   WebGpuRenderer    MetalRenderer    VulkanRenderer
      (Web)            (iOS)           (Android)
```

---

## Platform: Web (WebGPU)

### Why WebGPU
- Modern GPU API, successor to WebGL
- Better performance and lower overhead than WebGL
- Native blend mode support in shaders
- Fallback to WebGL2 for older browsers

### Implementation Steps

#### 1. WebGPU Context Setup
```dart
// lib/platform/web/webgpu_renderer.dart

@JS()
library webgpu;

import 'dart:js_interop';
import 'dart:typed_data';

class WebGpuRenderer implements GpuRenderer {
  GPUDevice? _device;
  GPUCanvasContext? _context;
  final Map<String, GPUTexture> _textures = {};

  Future<void> initialize(int width, int height) async {
    final adapter = await navigator.gpu.requestAdapter();
    _device = await adapter.requestDevice();
    // Setup render pipeline, shaders, etc.
  }
}
```

#### 2. Texture Management
```dart
Future<String> createTexture(int width, int height) async {
  final texture = _device!.createTexture(GPUTextureDescriptor(
    size: [width, height, 1],
    format: 'rgba8unorm',
    usage: GPUTextureUsage.TEXTURE_BINDING |
           GPUTextureUsage.COPY_DST |
           GPUTextureUsage.RENDER_ATTACHMENT,
  ));
  final id = 'tex_${_textures.length}';
  _textures[id] = texture;
  return id;
}

Future<void> updateTexture(String id, Uint8List pixels) async {
  _device!.queue.writeTexture(
    destination: GPUImageCopyTexture(texture: _textures[id]!),
    data: pixels,
    dataLayout: GPUImageDataLayout(bytesPerRow: width * 4),
    size: [width, height, 1],
  );
}
```

#### 3. Composite Shader (WGSL)
```wgsl
// shaders/composite.wgsl

@group(0) @binding(0) var baseTexture: texture_2d<f32>;
@group(0) @binding(1) var layerTexture: texture_2d<f32>;
@group(0) @binding(2) var texSampler: sampler;

struct Uniforms {
  opacity: f32,
  blendMode: u32,
}
@group(0) @binding(3) var<uniform> uniforms: Uniforms;

@fragment
fn main(@location(0) uv: vec2<f32>) -> @location(0) vec4<f32> {
  let base = textureSample(baseTexture, texSampler, uv);
  let layer = textureSample(layerTexture, texSampler, uv);
  let blended = applyBlendMode(base, layer, uniforms.blendMode);
  return mix(base, blended, layer.a * uniforms.opacity);
}

fn applyBlendMode(base: vec4<f32>, layer: vec4<f32>, mode: u32) -> vec4<f32> {
  switch(mode) {
    case 0u: { return layer; } // Normal
    case 1u: { return base * layer; } // Multiply
    case 2u: { return vec4(1.0) - (vec4(1.0) - base) * (vec4(1.0) - layer); } // Screen
    // ... other blend modes
    default: { return layer; }
  }
}
```

#### 4. Flutter Integration
```dart
// Use Texture widget to display GPU-rendered content
class GpuCanvas extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Texture(textureId: _flutterTextureId);
  }
}
```

### WebGL2 Fallback
For browsers without WebGPU support:
- Use `WebGL2RenderingContext`
- Same shader logic in GLSL
- Slightly different texture upload API

---

## Platform: iOS (Metal)

### Why Metal
- Apple's native GPU API
- Best performance on iOS/macOS
- Required for modern iOS apps targeting GPU

### Implementation Steps

#### 1. Flutter Platform Channel
```dart
// lib/platform/ios/metal_renderer.dart

class MetalRenderer implements GpuRenderer {
  static const _channel = MethodChannel('pixelforge/metal');

  Future<void> initialize(int width, int height) async {
    await _channel.invokeMethod('initialize', {
      'width': width,
      'height': height,
    });
  }

  Future<void> updateTexture(String id, Uint8List pixels) async {
    await _channel.invokeMethod('updateTexture', {
      'id': id,
      'pixels': pixels,
    });
  }
}
```

#### 2. Native Metal Code (Swift)
```swift
// ios/Runner/MetalRenderer.swift

import Metal
import Flutter

class MetalRenderer: NSObject, FlutterTexture {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var textures: [String: MTLTexture] = [:]
    private var outputTexture: MTLTexture!

    func initialize(width: Int, height: Int) {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!

        // Create output texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        outputTexture = device.makeTexture(descriptor: descriptor)!

        // Setup render pipeline with blend shaders
        setupPipeline()
    }

    func composite(layers: [(texture: MTLTexture, opacity: Float, blendMode: Int)]) {
        let commandBuffer = commandQueue.makeCommandBuffer()!

        for layer in layers {
            // Render each layer with blend mode
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentTexture(outputTexture, index: 0) // base
            encoder.setFragmentTexture(layer.texture, index: 1)  // layer
            encoder.setFragmentBytes(&layer.opacity, length: 4, index: 0)
            encoder.setFragmentBytes(&layer.blendMode, length: 4, index: 1)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    // FlutterTexture protocol - provides CVPixelBuffer to Flutter
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        // Convert MTLTexture to CVPixelBuffer for Flutter
    }
}
```

#### 3. Metal Shader (MSL)
```metal
// ios/Runner/Shaders.metal

#include <metal_stdlib>
using namespace metal;

fragment float4 compositeFragment(
    float2 uv [[stage_in]],
    texture2d<float> baseTexture [[texture(0)]],
    texture2d<float> layerTexture [[texture(1)]],
    constant float& opacity [[buffer(0)]],
    constant int& blendMode [[buffer(1)]]
) {
    constexpr sampler s(filter::nearest);
    float4 base = baseTexture.sample(s, uv);
    float4 layer = layerTexture.sample(s, uv);

    float4 blended;
    switch(blendMode) {
        case 0: blended = layer; break; // Normal
        case 1: blended = base * layer; break; // Multiply
        case 2: blended = 1.0 - (1.0 - base) * (1.0 - layer); break; // Screen
        // ... other blend modes
        default: blended = layer;
    }

    return mix(base, blended, layer.a * opacity);
}
```

#### 4. Register with Flutter
```swift
// ios/Runner/AppDelegate.swift

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    private var metalRenderer: MetalRenderer!

    override func application(...) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "pixelforge/metal", binaryMessenger: controller.binaryMessenger)

        metalRenderer = MetalRenderer()

        // Register texture with Flutter
        let textureRegistry = controller.engine!.textureRegistry
        let textureId = textureRegistry.register(metalRenderer)

        channel.setMethodCallHandler { [weak self] call, result in
            // Handle method calls from Dart
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

---

## Platform: Android (Vulkan / OpenGL ES)

### Why Vulkan
- Modern, low-overhead GPU API
- Better performance than OpenGL ES
- Fallback to OpenGL ES 3.0 for older devices

### Implementation Steps

#### 1. Flutter Platform Channel
```dart
// lib/platform/android/vulkan_renderer.dart

class VulkanRenderer implements GpuRenderer {
  static const _channel = MethodChannel('pixelforge/vulkan');

  // Same interface as MetalRenderer
}
```

#### 2. Native Vulkan Code (Kotlin + NDK)
```kotlin
// android/app/src/main/kotlin/VulkanRenderer.kt

class VulkanRenderer(private val flutterEngine: FlutterEngine) : FlutterTexture {
    private external fun nativeInit(width: Int, height: Int): Long
    private external fun nativeUpdateTexture(handle: Long, id: String, pixels: ByteArray)
    private external fun nativeComposite(handle: Long, layers: Array<LayerInfo>)
    private external fun nativeGetSurfaceTexture(handle: Long): SurfaceTexture

    companion object {
        init {
            System.loadLibrary("pixelforge_vulkan")
        }
    }

    private var nativeHandle: Long = 0

    fun initialize(width: Int, height: Int) {
        nativeHandle = nativeInit(width, height)

        // Register with Flutter texture registry
        val textureEntry = flutterEngine.renderer.createSurfaceTexture()
        // ...
    }
}
```

#### 3. Vulkan NDK Implementation (C++)
```cpp
// android/app/src/main/cpp/vulkan_renderer.cpp

#include <vulkan/vulkan.h>
#include <jni.h>

class VulkanRenderer {
    VkDevice device;
    VkQueue queue;
    VkCommandPool commandPool;
    std::map<std::string, VkImage> textures;

public:
    void initialize(int width, int height) {
        // Create Vulkan instance, device, queue
        // Setup render pipeline
        // Create output image
    }

    void composite(const std::vector<LayerInfo>& layers) {
        VkCommandBuffer cmd = beginCommandBuffer();

        for (const auto& layer : layers) {
            // Bind textures, set uniforms, draw quad
            // Apply blend mode in fragment shader
        }

        endCommandBuffer(cmd);
        submitAndWait(cmd);
    }
};

extern "C" JNIEXPORT jlong JNICALL
Java_com_pixelforge_VulkanRenderer_nativeInit(JNIEnv* env, jobject, jint width, jint height) {
    auto renderer = new VulkanRenderer();
    renderer->initialize(width, height);
    return reinterpret_cast<jlong>(renderer);
}
```

#### 4. Vulkan Shader (GLSL → SPIR-V)
```glsl
// shaders/composite.frag (compile with glslc to SPIR-V)

#version 450

layout(binding = 0) uniform sampler2D baseTexture;
layout(binding = 1) uniform sampler2D layerTexture;

layout(push_constant) uniform PushConstants {
    float opacity;
    int blendMode;
} pc;

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 outColor;

void main() {
    vec4 base = texture(baseTexture, uv);
    vec4 layer = texture(layerTexture, uv);

    vec4 blended;
    switch(pc.blendMode) {
        case 0: blended = layer; break;
        case 1: blended = base * layer; break;
        case 2: blended = vec4(1.0) - (vec4(1.0) - base) * (vec4(1.0) - layer); break;
        default: blended = layer;
    }

    outColor = mix(base, blended, layer.a * pc.opacity);
}
```

### OpenGL ES 3.0 Fallback
For devices without Vulkan:
- Use `GLSurfaceView` or `TextureView`
- Same shader logic in GLSL ES 3.0
- Slightly higher overhead but broader compatibility

---

## Implementation Phases

### Phase 1: Abstract Interface (1-2 days)
```dart
// lib/platform/gpu_renderer.dart

abstract class GpuRenderer {
  Future<void> initialize(int width, int height);
  Future<String> createTexture(int width, int height);
  Future<void> updateTexture(String id, int x, int y, int w, int h, Uint8List pixels);
  Future<void> deleteTexture(String id);
  Future<void> composite(List<RenderLayer> layers);
  Future<ui.Image> toImage();
  void dispose();
}

class RenderLayer {
  final String textureId;
  final double opacity;
  final BlendMode blendMode;
  final bool visible;
}
```

### Phase 2: Web Implementation (3-5 days)
1. WebGPU renderer with WGSL shaders
2. WebGL2 fallback
3. Integration with Flutter web

### Phase 3: iOS Implementation (3-5 days)
1. Metal renderer with MSL shaders
2. Flutter texture registration
3. Platform channel bridge

### Phase 4: Android Implementation (5-7 days)
1. Vulkan renderer with NDK
2. OpenGL ES fallback
3. Flutter texture registration
4. Platform channel bridge

### Phase 5: Integration & Optimization (3-5 days)
1. Wire `GpuCompositor` to use platform renderers
2. Dirty region tracking (only upload changed pixels)
3. Texture caching per Cel
4. Performance benchmarking

---

## Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| 8 layers @ 1024x1024 | < 4ms | ~50ms (CPU) |
| 16 layers @ 512x512 | < 2ms | ~25ms (CPU) |
| Single pixel update | < 1ms | ~5ms (CPU) |
| Memory per layer | ~4MB | ~4MB |

---

## Files to Create

```
lib/
├── platform/
│   ├── gpu_renderer.dart          # Abstract interface
│   ├── gpu_compositor.dart        # Orchestrates rendering
│   ├── web/
│   │   ├── webgpu_renderer.dart
│   │   └── webgl_renderer.dart
│   ├── ios/
│   │   └── metal_renderer.dart
│   └── android/
│       └── vulkan_renderer.dart

ios/Runner/
├── MetalRenderer.swift
├── Shaders.metal
└── PixelForgePlugin.swift

android/app/src/main/
├── kotlin/.../VulkanRenderer.kt
└── cpp/
    ├── vulkan_renderer.cpp
    └── shaders/composite.frag

web/
└── gpu_worker.js  # Optional: offload to web worker
```

---

## References

- [WebGPU Spec](https://www.w3.org/TR/webgpu/)
- [Metal Best Practices](https://developer.apple.com/documentation/metal)
- [Vulkan Tutorial](https://vulkan-tutorial.com/)
- [Flutter External Textures](https://api.flutter.dev/flutter/services/TextureRegistry-class.html)
- [Blend Mode Math](https://www.w3.org/TR/compositing-1/#blending)
