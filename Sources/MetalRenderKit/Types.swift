//
//  Types.swift
//  MetalRenderKit
//
//  Created by Miguel Carlos Elizondo Mrtinez on 17/10/25.
//

import simd

public struct MRMaterial: Sendable, Hashable {
    public var baseColor: SIMD3<Float> = [0.9,0.6,0.3]
    public var metallic:  Float = 0
    public var roughness: Float = 0.6
    public init(baseColor: SIMD3<Float> = [0.9,0.6,0.3], metallic: Float = 0, roughness: Float = 0.6) {
        self.baseColor = baseColor; self.metallic = metallic; self.roughness = roughness
    }
}

public struct MRDirectionalLight: Sendable, Hashable {
    public var direction: SIMD3<Float> = simd_normalize([0.6,1.0,0.3])
    public var color: SIMD3<Float> = [1,1,1]
    public var intensity: Float = 1
    public init(direction: SIMD3<Float> = [0.6,1.0,0.3], color: SIMD3<Float> = [1,1,1], intensity: Float = 1) {
        self.direction = simd_normalize(direction); self.color = color; self.intensity = intensity
    }
}

public struct MRCamera: Sendable, Hashable {
    public var position: SIMD3<Float> = [0,1.6,3.8]
    public var target:   SIMD3<Float> = [0,1,0]
    public var up:       SIMD3<Float> = [0,1,0]
    public var fovY:     Float = 60 * .pi/180
    public var nearZ:    Float = 0.01
    public var farZ:     Float = 100
}

public enum MRCullMode: Sendable { case none, back, front }

public struct MRClear: Sendable, Hashable {
    public var color: SIMD4<Float> = [0.08,0.09,0.11,1]
    public var depth: Double = 1.0
    public init(color: SIMD4<Float> = [0.08,0.09,0.11,1], depth: Double = 1.0) { self.color = color; self.depth = depth }
}

public func mrPerspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let y = 1 / tanf(fovY * 0.5), x = y / aspect, z = far / (near - far)
    return simd_float4x4(
        SIMD4<Float>( x,0,0,0), SIMD4<Float>(0, y,0,0),
        SIMD4<Float>(0,0, z,-1), SIMD4<Float>(0,0, z*near,0))
}
public func mrLookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let f = simd_normalize(center - eye), s = simd_normalize(simd_cross(f, up)), u = simd_cross(s, f)
    let M = simd_float4x4(SIMD4<Float>( s.x, u.x,-f.x,0), SIMD4<Float>( s.y, u.y,-f.y,0),
                          SIMD4<Float>( s.z, u.z,-f.z,0), SIMD4<Float>(0,0,0,1))
    let T = simd_float4x4(SIMD4<Float>(1,0,0,0), SIMD4<Float>(0,1,0,0),
                          SIMD4<Float>(0,0,1,0), SIMD4<Float>(-eye.x,-eye.y,-eye.z,1))
    return M * T
}
public extension simd_float4x4 {
    static func scale(_ sx: Float,_ sy: Float,_ sz: Float) -> simd_float4x4 {
        simd_float4x4(SIMD4<Float>(sx,0,0,0), SIMD4<Float>(0,sy,0,0),
                      SIMD4<Float>(0,0,sz,0), SIMD4<Float>(0,0,0,1))
    }
    static func translate(_ t: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(SIMD4<Float>(1,0,0,0), SIMD4<Float>(0,1,0,0),
                      SIMD4<Float>(0,0,1,0), SIMD4<Float>(t.x,t.y,t.z,1))
    }
}
