//
//  Renderer.swift
//  MetalRenderKit
//
//  Created by Miguel Carlos Elizondo Mrtinez on 17/10/25.
//

import Metal, MetalKit, simd
import Generator3D

public struct MRFrameUniforms {
    var viewProj: simd_float4x4
    var lightDir: SIMD3<Float>; var _pad0: Float = 0
    var lightColInt: SIMD4<Float>
    var camPos: SIMD3<Float>; var _pad1: Float = 0
}
public struct MRModelUniforms {
    var model: simd_float4x4
    var baseColor: SIMD3<Float>
    var metallic: Float
    var roughness: Float
    var _pad2: SIMD2<Float> = .zero
}
public struct MRInstance: Sendable, Hashable { public let id: UUID; public init(id: UUID = UUID()) { self.id = id } }
struct _MRInstanceData {
    var model: simd_float4x4
    var material: MRMaterial
    var buffers: G3DMetalBuffers
}

@MainActor
public final class MRRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState

    public var camera = MRCamera()
    public var light  = MRDirectionalLight()
    public var clear  = MRClear()
    public var cullMode: MRCullMode = .back

    public var onUpdate: ((Float) -> Void)? // callback por frame (dt en segundos)

    private var instances: [UUID: _MRInstanceData] = [:]
    private var viewProj = matrix_identity_float4x4
    private var lastTime: CFTimeInterval = CACurrentMediaTime()

    public init(mtkView: MTKView) {
        let dev = mtkView.device ?? MTLCreateSystemDefaultDevice()!
        device = dev
        queue  = dev.makeCommandQueue()!

        let lib  = try! dev.makeDefaultLibrary(bundle: .module)
        let vfn  = lib.makeFunction(name: "mr_v_main")!
        let ffn  = lib.makeFunction(name: "mr_f_main")!

        let vdesc = MTLVertexDescriptor()
        vdesc.attributes[0].format = .float3; vdesc.attributes[0].bufferIndex = 0
        vdesc.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        vdesc.attributes[1].format = .float3; vdesc.attributes[1].bufferIndex = 1
        vdesc.layouts[1].stride = MemoryLayout<SIMD3<Float>>.stride
        vdesc.attributes[2].format = .float2; vdesc.attributes[2].bufferIndex = 2
        vdesc.layouts[2].stride = MemoryLayout<SIMD2<Float>>.stride

        let pdesc = MTLRenderPipelineDescriptor()
        pdesc.vertexFunction = vfn; pdesc.fragmentFunction = ffn
        pdesc.vertexDescriptor = vdesc
        pdesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pdesc.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pdesc.sampleCount = mtkView.sampleCount
        pipeline = try! dev.makeRenderPipelineState(descriptor: pdesc)

        let ddesc = MTLDepthStencilDescriptor()
        ddesc.depthCompareFunction = .less
        ddesc.isDepthWriteEnabled = true
        depthState = dev.makeDepthStencilState(descriptor: ddesc)!

        super.init()
        updateViewProj(drawableSize: mtkView.drawableSize)

        mtkView.device = dev
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.sampleCount = 1
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.delegate = self
    }

    @discardableResult
    public func addInstance(mesh: G3DMesh, material: MRMaterial, model: simd_float4x4) -> MRInstance {
        let buffers = try! G3DMetalBridge.makeBuffers(device: device, mesh: mesh)
        let id = UUID()
        instances[id] = _MRInstanceData(model: model, material: material, buffers: buffers)
        return MRInstance(id: id)
    }
    public func updateInstance(_ inst: MRInstance, model: simd_float4x4? = nil, material: MRMaterial? = nil) {
        guard var d = instances[inst.id] else { return }
        if let m = model { d.model = m }
        if let mat = material { d.material = mat }
        instances[inst.id] = d
    }
    public func removeInstance(_ inst: MRInstance) { instances.removeValue(forKey: inst.id) }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { updateViewProj(drawableSize: size) }

    public func draw(in view: MTKView) {
        // dt + callback de simulación
        let now = CACurrentMediaTime(); let dt = Float(now - lastTime); lastTime = now
        onUpdate?(dt)

        guard let pass = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }

        pass.colorAttachments[0].clearColor = .init(red: Double(clear.color.x), green: Double(clear.color.y), blue: Double(clear.color.z), alpha: Double(clear.color.w))
        pass.depthAttachment.clearDepth = clear.depth

        enc.setRenderPipelineState(pipeline)
        enc.setDepthStencilState(depthState)
        switch cullMode { case .none: enc.setCullMode(.none); case .back: enc.setCullMode(.back); case .front: enc.setCullMode(.front) }

        var F = MRFrameUniforms(viewProj: viewProj,
                                lightDir: light.direction,
                                lightColInt: SIMD4<Float>(light.color * light.intensity, 1),
                                camPos: camera.position)
        enc.setVertexBytes(&F, length: MemoryLayout<MRFrameUniforms>.stride, index: 3)
        enc.setFragmentBytes(&F, length: MemoryLayout<MRFrameUniforms>.stride, index: 1)

        for (_, d) in instances {
            enc.setVertexBuffer(d.buffers.vbPositions, offset: 0, index: 0)
            enc.setVertexBuffer(d.buffers.vbNormals,   offset: 0, index: 1)
            enc.setVertexBuffer(d.buffers.vbUVs,       offset: 0, index: 2)

            var M = MRModelUniforms(model: d.model,
                                    baseColor: d.material.baseColor,
                                    metallic: d.material.metallic,
                                    roughness: d.material.roughness)
            enc.setVertexBytes(&M, length: MemoryLayout<MRModelUniforms>.stride, index: 4)
            enc.setFragmentBytes(&M, length: MemoryLayout<MRModelUniforms>.stride, index: 0)

            enc.drawIndexedPrimitives(type: .triangle,
                                      indexCount: d.buffers.indexCount,
                                      indexType: d.buffers.indexType,
                                      indexBuffer: d.buffers.ib,
                                      indexBufferOffset: 0)
        }

        enc.endEncoding()
        if let drawable = view.currentDrawable { cmd.present(drawable) }
        cmd.commit()
    }

    private func updateViewProj(drawableSize: CGSize) {
        let aspect = Float(max(1, drawableSize.width / max(1, drawableSize.height)))
        let proj = mrPerspective(fovY: camera.fovY, aspect: aspect, near: camera.nearZ, far: camera.farZ)
        let view = mrLookAt(eye: camera.position, center: camera.target, up: camera.up)
        viewProj = proj * view
    }
}
