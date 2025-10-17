//
//  MetalView.swift
//  MetalRenderKit
//
//  Created by Miguel Carlos Elizondo Mrtinez on 17/10/25.
//

import SwiftUI
import MetalKit

#if os(macOS)
import AppKit

public struct MRMetalView: NSViewRepresentable {
    public let renderer: MRRenderer
    public init(renderer: MRRenderer) { self.renderer = renderer }

    public func makeNSView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = renderer.device
        v.colorPixelFormat = .bgra8Unorm
        v.depthStencilPixelFormat = .depth32Float
        v.delegate = renderer as? MTKViewDelegate
        v.isPaused = false
        v.enableSetNeedsDisplay = false
        return v
    }

    public func updateNSView(_ view: MTKView, context: Context) {}
}

#else
import UIKit

public struct MRMetalView: UIViewRepresentable {
    public let renderer: MRRenderer
    public init(renderer: MRRenderer) { self.renderer = renderer }

    public func makeUIView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = renderer.device
        v.colorPixelFormat = .bgra8Unorm
        v.depthStencilPixelFormat = .depth32Float
        v.delegate = renderer as? MTKViewDelegate
        v.isPaused = false
        v.enableSetNeedsDisplay = false
        return v
    }

    public func updateUIView(_ view: MTKView, context: Context) {}
}
#endif
