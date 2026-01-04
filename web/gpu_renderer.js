/**
 * WebGPU Renderer for PixelForge
 *
 * Provides high-performance pixel manipulation using WebGPU storage textures
 * and compute shaders. Falls back to Canvas 2D when WebGPU is unavailable.
 */

class GpuRenderer {
  constructor() {
    this.device = null;
    this.context = null;
    this.canvas = null;
    this.width = 0;
    this.height = 0;
    this.layers = new Map();
    this.nextLayerId = 1;
    this.isInitialized = false;
    this.useFallback = false;
    this.fallbackCanvas = null;
    this.fallbackCtx = null;

    // Compute pipeline for batch pixel updates
    this.computePipeline = null;
    this.renderPipeline = null;

    // Bind group layouts
    this.computeBindGroupLayout = null;
    this.renderBindGroupLayout = null;
  }

  /**
   * Check if WebGPU is available.
   */
  static async isAvailable() {
    if (!navigator.gpu) return false;
    try {
      const adapter = await navigator.gpu.requestAdapter();
      return adapter !== null;
    } catch (e) {
      return false;
    }
  }

  /**
   * Initialize the renderer with given dimensions.
   */
  async initialize(width, height) {
    this.width = width;
    this.height = height;

    if (!await GpuRenderer.isAvailable()) {
      console.log('WebGPU not available, using Canvas 2D fallback');
      this._initFallback(width, height);
      return true;
    }

    try {
      const adapter = await navigator.gpu.requestAdapter();
      this.device = await adapter.requestDevice();

      // Create offscreen canvas for rendering
      this.canvas = new OffscreenCanvas(width, height);
      this.context = this.canvas.getContext('webgpu');

      const format = navigator.gpu.getPreferredCanvasFormat();
      this.context.configure({
        device: this.device,
        format: format,
        alphaMode: 'premultiplied',
      });

      this._createPipelines(format);
      this.isInitialized = true;
      return true;
    } catch (e) {
      console.error('WebGPU initialization failed:', e);
      this._initFallback(width, height);
      return true;
    }
  }

  _initFallback(width, height) {
    this.useFallback = true;
    this.fallbackCanvas = new OffscreenCanvas(width, height);
    this.fallbackCtx = this.fallbackCanvas.getContext('2d');
    this.isInitialized = true;
  }

  _createPipelines(format) {
    // Compute shader for batch pixel updates
    const computeShaderCode = `
      struct PixelUpdate {
        x: u32,
        y: u32,
        color: u32,
      };

      @group(0) @binding(0) var outputTexture: texture_storage_2d<rgba8unorm, write>;
      @group(0) @binding(1) var<storage, read> updates: array<PixelUpdate>;
      @group(0) @binding(2) var<uniform> updateCount: u32;

      @compute @workgroup_size(64)
      fn main(@builtin(global_invocation_id) id: vec3<u32>) {
        let idx = id.x;
        if (idx >= updateCount) { return; }

        let update = updates[idx];
        let r = f32((update.color >> 24u) & 0xFFu) / 255.0;
        let g = f32((update.color >> 16u) & 0xFFu) / 255.0;
        let b = f32((update.color >> 8u) & 0xFFu) / 255.0;
        let a = f32(update.color & 0xFFu) / 255.0;

        textureStore(outputTexture, vec2<u32>(update.x, update.y), vec4<f32>(r, g, b, a));
      }
    `;

    const computeModule = this.device.createShaderModule({
      code: computeShaderCode,
    });

    this.computeBindGroupLayout = this.device.createBindGroupLayout({
      entries: [
        { binding: 0, visibility: GPUShaderStage.COMPUTE, storageTexture: { format: 'rgba8unorm', access: 'write-only' } },
        { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'read-only-storage' } },
        { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'uniform' } },
      ],
    });

    this.computePipeline = this.device.createComputePipeline({
      layout: this.device.createPipelineLayout({
        bindGroupLayouts: [this.computeBindGroupLayout],
      }),
      compute: {
        module: computeModule,
        entryPoint: 'main',
      },
    });

    // Render shader for compositing layers
    const renderShaderCode = `
      struct VertexOutput {
        @builtin(position) position: vec4<f32>,
        @location(0) texCoord: vec2<f32>,
      };

      @vertex
      fn vertexMain(@builtin(vertex_index) idx: u32) -> VertexOutput {
        var positions = array<vec2<f32>, 6>(
          vec2<f32>(-1.0, -1.0), vec2<f32>(1.0, -1.0), vec2<f32>(-1.0, 1.0),
          vec2<f32>(-1.0, 1.0), vec2<f32>(1.0, -1.0), vec2<f32>(1.0, 1.0),
        );
        var texCoords = array<vec2<f32>, 6>(
          vec2<f32>(0.0, 1.0), vec2<f32>(1.0, 1.0), vec2<f32>(0.0, 0.0),
          vec2<f32>(0.0, 0.0), vec2<f32>(1.0, 1.0), vec2<f32>(1.0, 0.0),
        );

        var output: VertexOutput;
        output.position = vec4<f32>(positions[idx], 0.0, 1.0);
        output.texCoord = texCoords[idx];
        return output;
      }

      @group(0) @binding(0) var layerTexture: texture_2d<f32>;
      @group(0) @binding(1) var layerSampler: sampler;
      @group(0) @binding(2) var<uniform> opacity: f32;

      @fragment
      fn fragmentMain(input: VertexOutput) -> @location(0) vec4<f32> {
        var color = textureSample(layerTexture, layerSampler, input.texCoord);
        color.a *= opacity;
        return color;
      }
    `;

    const renderModule = this.device.createShaderModule({
      code: renderShaderCode,
    });

    this.renderBindGroupLayout = this.device.createBindGroupLayout({
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: {} },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: {} },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, buffer: { type: 'uniform' } },
      ],
    });

    this.renderPipeline = this.device.createRenderPipeline({
      layout: this.device.createPipelineLayout({
        bindGroupLayouts: [this.renderBindGroupLayout],
      }),
      vertex: {
        module: renderModule,
        entryPoint: 'vertexMain',
      },
      fragment: {
        module: renderModule,
        entryPoint: 'fragmentMain',
        targets: [{
          format: format,
          blend: {
            color: { srcFactor: 'src-alpha', dstFactor: 'one-minus-src-alpha', operation: 'add' },
            alpha: { srcFactor: 'one', dstFactor: 'one-minus-src-alpha', operation: 'add' },
          },
        }],
      },
      primitive: { topology: 'triangle-list' },
    });

    // Create sampler for rendering
    this.sampler = this.device.createSampler({
      magFilter: 'nearest',
      minFilter: 'nearest',
    });
  }

  /**
   * Create a new layer/texture.
   * Returns the layer ID.
   */
  createLayer(width, height) {
    const id = this.nextLayerId++;

    if (this.useFallback) {
      const canvas = new OffscreenCanvas(width, height);
      const ctx = canvas.getContext('2d');
      this.layers.set(id, { canvas, ctx, width, height });
    } else {
      const texture = this.device.createTexture({
        size: [width, height],
        format: 'rgba8unorm',
        usage: GPUTextureUsage.TEXTURE_BINDING |
               GPUTextureUsage.STORAGE_BINDING |
               GPUTextureUsage.COPY_DST |
               GPUTextureUsage.RENDER_ATTACHMENT,
      });

      this.layers.set(id, { texture, width, height });
    }

    return id;
  }

  /**
   * Delete a layer and free its resources.
   */
  deleteLayer(layerId) {
    const layer = this.layers.get(layerId);
    if (!layer) return false;

    if (!this.useFallback && layer.texture) {
      layer.texture.destroy();
    }

    this.layers.delete(layerId);
    return true;
  }

  /**
   * Update pixels in a layer using batch compute shader.
   * updates: Array of {x, y, color} objects where color is 0xRRGGBBAA
   */
  updatePixels(layerId, updates) {
    const layer = this.layers.get(layerId);
    if (!layer || updates.length === 0) return;

    if (this.useFallback) {
      this._updatePixelsFallback(layer, updates);
      return;
    }

    // Create buffer for updates
    const updateData = new Uint32Array(updates.length * 3);
    for (let i = 0; i < updates.length; i++) {
      updateData[i * 3] = updates[i].x;
      updateData[i * 3 + 1] = updates[i].y;
      updateData[i * 3 + 2] = updates[i].color;
    }

    const updateBuffer = this.device.createBuffer({
      size: updateData.byteLength,
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    });
    this.device.queue.writeBuffer(updateBuffer, 0, updateData);

    // Create uniform buffer for count
    const countBuffer = this.device.createBuffer({
      size: 4,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    this.device.queue.writeBuffer(countBuffer, 0, new Uint32Array([updates.length]));

    // Create bind group
    const bindGroup = this.device.createBindGroup({
      layout: this.computeBindGroupLayout,
      entries: [
        { binding: 0, resource: layer.texture.createView() },
        { binding: 1, resource: { buffer: updateBuffer } },
        { binding: 2, resource: { buffer: countBuffer } },
      ],
    });

    // Dispatch compute shader
    const commandEncoder = this.device.createCommandEncoder();
    const passEncoder = commandEncoder.beginComputePass();
    passEncoder.setPipeline(this.computePipeline);
    passEncoder.setBindGroup(0, bindGroup);
    passEncoder.dispatchWorkgroups(Math.ceil(updates.length / 64));
    passEncoder.end();

    this.device.queue.submit([commandEncoder.finish()]);

    // Cleanup
    updateBuffer.destroy();
    countBuffer.destroy();
  }

  _updatePixelsFallback(layer, updates) {
    const imageData = layer.ctx.getImageData(0, 0, layer.width, layer.height);
    const data = imageData.data;

    for (const update of updates) {
      const idx = (update.y * layer.width + update.x) * 4;
      data[idx] = (update.color >> 24) & 0xFF;     // R
      data[idx + 1] = (update.color >> 16) & 0xFF; // G
      data[idx + 2] = (update.color >> 8) & 0xFF;  // B
      data[idx + 3] = update.color & 0xFF;         // A
    }

    layer.ctx.putImageData(imageData, 0, 0);
  }

  /**
   * Update a rectangular region with raw RGBA data.
   */
  updateRegion(layerId, x, y, width, height, data) {
    const layer = this.layers.get(layerId);
    if (!layer) return;

    if (this.useFallback) {
      const imageData = new ImageData(new Uint8ClampedArray(data), width, height);
      layer.ctx.putImageData(imageData, x, y);
      return;
    }

    this.device.queue.writeTexture(
      { texture: layer.texture, origin: [x, y] },
      data,
      { bytesPerRow: width * 4 },
      [width, height]
    );
  }

  /**
   * Clear a layer to a solid color.
   */
  clearLayer(layerId, color) {
    const layer = this.layers.get(layerId);
    if (!layer) return;

    if (this.useFallback) {
      const r = (color >> 24) & 0xFF;
      const g = (color >> 16) & 0xFF;
      const b = (color >> 8) & 0xFF;
      const a = ((color & 0xFF) / 255).toFixed(3);
      layer.ctx.fillStyle = `rgba(${r},${g},${b},${a})`;
      layer.ctx.fillRect(0, 0, layer.width, layer.height);
      return;
    }

    // Use render pass to clear
    const commandEncoder = this.device.createCommandEncoder();
    const passEncoder = commandEncoder.beginRenderPass({
      colorAttachments: [{
        view: layer.texture.createView(),
        clearValue: {
          r: ((color >> 24) & 0xFF) / 255,
          g: ((color >> 16) & 0xFF) / 255,
          b: ((color >> 8) & 0xFF) / 255,
          a: (color & 0xFF) / 255,
        },
        loadOp: 'clear',
        storeOp: 'store',
      }],
    });
    passEncoder.end();
    this.device.queue.submit([commandEncoder.finish()]);
  }

  /**
   * Render all layers to the output canvas.
   * layers: Array of {id, zIndex, opacity, visible} sorted by zIndex
   */
  render(layers) {
    if (this.useFallback) {
      this._renderFallback(layers);
      return;
    }

    const commandEncoder = this.device.createCommandEncoder();
    const textureView = this.context.getCurrentTexture().createView();

    // Clear the output
    const passEncoder = commandEncoder.beginRenderPass({
      colorAttachments: [{
        view: textureView,
        clearValue: { r: 0, g: 0, b: 0, a: 0 },
        loadOp: 'clear',
        storeOp: 'store',
      }],
    });

    // Sort by zIndex and render each visible layer
    const sortedLayers = [...layers].sort((a, b) => a.zIndex - b.zIndex);

    for (const layerInfo of sortedLayers) {
      if (!layerInfo.visible) continue;

      const layer = this.layers.get(layerInfo.id);
      if (!layer) continue;

      // Create opacity uniform buffer
      const opacityBuffer = this.device.createBuffer({
        size: 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
      });
      this.device.queue.writeBuffer(opacityBuffer, 0, new Float32Array([layerInfo.opacity]));

      const bindGroup = this.device.createBindGroup({
        layout: this.renderBindGroupLayout,
        entries: [
          { binding: 0, resource: layer.texture.createView() },
          { binding: 1, resource: this.sampler },
          { binding: 2, resource: { buffer: opacityBuffer } },
        ],
      });

      passEncoder.setPipeline(this.renderPipeline);
      passEncoder.setBindGroup(0, bindGroup);
      passEncoder.draw(6);

      // Note: In a real implementation, we'd pool these buffers
      // For now, we accept the overhead for correctness
    }

    passEncoder.end();
    this.device.queue.submit([commandEncoder.finish()]);
  }

  _renderFallback(layers) {
    this.fallbackCtx.clearRect(0, 0, this.width, this.height);

    const sortedLayers = [...layers].sort((a, b) => a.zIndex - b.zIndex);

    for (const layerInfo of sortedLayers) {
      if (!layerInfo.visible) continue;

      const layer = this.layers.get(layerInfo.id);
      if (!layer) continue;

      this.fallbackCtx.globalAlpha = layerInfo.opacity;
      this.fallbackCtx.drawImage(layer.canvas, 0, 0);
    }

    this.fallbackCtx.globalAlpha = 1;
  }

  /**
   * Get the rendered output as an ImageBitmap.
   */
  async toImageBitmap() {
    if (this.useFallback) {
      return createImageBitmap(this.fallbackCanvas);
    }
    return createImageBitmap(this.canvas);
  }

  /**
   * Resize the output canvas.
   */
  resize(width, height) {
    this.width = width;
    this.height = height;

    if (this.useFallback) {
      this.fallbackCanvas.width = width;
      this.fallbackCanvas.height = height;
    } else {
      this.canvas.width = width;
      this.canvas.height = height;

      const format = navigator.gpu.getPreferredCanvasFormat();
      this.context.configure({
        device: this.device,
        format: format,
        alphaMode: 'premultiplied',
      });
    }
  }

  /**
   * Dispose of all GPU resources.
   */
  dispose() {
    for (const [id, layer] of this.layers) {
      if (!this.useFallback && layer.texture) {
        layer.texture.destroy();
      }
    }
    this.layers.clear();
    this.isInitialized = false;
  }
}

// Expose to global scope for Flutter interop
window.GpuRenderer = GpuRenderer;
