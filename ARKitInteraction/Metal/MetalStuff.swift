////
////  Renderer.swift
////  MetalAR
////
////  Created by Arthur Tonelli on 9/7/20.
////  Copyright © 2020 Arthur Tonelli. All rights reserved.
////
//
//import Foundation
//import Metal
//import MetalKit
//import ARKit
//
//
//class MetalStuff {
//    var device: MTLDevice
//    var defaultLib: MTLLibrary?
//    var grayscaleShader: MTLFunction?
//    var verctorShader: MTLFunction?
//    var fragmentShader: MTLFunction?
//    var commandQueue: MTLCommandQueue?
//    var commandBuffer: MTLCommandBuffer?
//    var commandEncoder: MTLComputeCommandEncoder?
//    var pipelineState: MTLComputePipelineState?
//    var inputImage: UIImage
//    var height, width: Int
//    // most devices have a limit of 512 threads per group
//    let threadsPerBlock = MTLSize(width: 16, height: 16, depth: 1)
//    
//    
//    init() {
//        self.device = MTLCreateSystemDefaultDevice()!
//        self.defaultLib = self.device.makeDefaultLibrary()
//        self.grayscaleShader = self.defaultLib?.makeFunction(name: "black")
//        self.verctorShader = self.defaultLib?.makeFunction(name: "capturedImageVertexTransform")
//        self.fragmentShader = self.defaultLib?.makeFunction(name: "capturedImageFragmentShader")
//        self.commandQueue = self.device.makeCommandQueue()
//        self.commandBuffer = self.commandQueue?.makeCommandBuffer()
//        self.commandEncoder = self.commandBuffer?.makeComputeCommandEncoder()
//        
//        let pipelineDescriptor = MTLRenderPipelineDescriptor()
//        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
//        pipelineDescriptor.vertexFunction = self.verctorShader
//        pipelineDescriptor.fragmentFunction = self.fragmentShader
//        
//        self.pipelineState = try? self.device.makeComputeCommandEncoder(descriptor: pipelineDescriptor)
//        
//        commandQueue = self.device.makeCommandQueue()
//        
////        self.inputImage = UIImage(named: "spidey.jpg")!
////        self.height = Int(self.inputImage.size.height)
//    }
//    
//    func drawRectResized(size: CGSize) {
//        viewportSize = size
//        viewportSizeDidChange = true
//    }
//    
//    func convert() {
//        // Wait to ensure only kMaxBuffersInFlight are getting proccessed by any stage in the Metal
//        //   pipeline (App, Metal, Drivers, GPU, etc)
//        let _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
//        
//        // Create a new command buffer for each renderpass to the current drawable
//        if let commandBuffer = commandQueue.makeCommandBuffer() {
//            commandBuffer.label = "MyCommand"
//            
//            // Add completion hander which signal _inFlightSemaphore when Metal and the GPU has fully
//            //   finished proccssing the commands we're encoding this frame.  This indicates when the
//            //   dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
//            //   and the GPU.
//            // Retain our CVMetalTextures for the duration of the rendering cycle. The MTLTextures
//            //   we use from the CVMetalTextures are not valid unless their parent CVMetalTextures
//            //   are retained. Since we may release our CVMetalTexture ivars during the rendering
//            //   cycle, we must retain them separately here.
//            var textures = [capturedImageTextureY, capturedImageTextureCbCr]
//            commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
//                if let strongSelf = self {
//                    strongSelf.inFlightSemaphore.signal()
//                }
//                textures.removeAll()
//            }
//            
//            updateBufferStates()
//            updateGameState()
//            
//            if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor, let currentDrawable = renderDestination.currentDrawable, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
//                
//                renderEncoder.label = "MyRenderEncoder"
//                
//                drawCapturedImage(renderEncoder: renderEncoder)
//                drawAnchorGeometry(renderEncoder: renderEncoder)
//                
//                // We're done encoding commands
//                renderEncoder.endEncoding()
//                
//                // Schedule a present once the framebuffer is complete using the current drawable
//                commandBuffer.present(currentDrawable)
//            }
//            
//            // Finalize rendering here & push the command buffer to the GPU
//            commandBuffer.commit()
//        }
//    }
//    
//    // MARK: - Private
//    
//    func loadMetal() {
//        // Create and load our basic Metal state objects
//        
//        // Set the default formats needed to render
//        renderDestination.depthStencilPixelFormat = .depth32Float_stencil8
//        renderDestination.colorPixelFormat = .bgra8Unorm
//        renderDestination.sampleCount = 1
//        
//        // Calculate our uniform buffer sizes. We allocate kMaxBuffersInFlight instances for uniform
//        //   storage in a single buffer. This allows us to update uniforms in a ring (i.e. triple
//        //   buffer the uniforms) so that the GPU reads from one slot in the ring wil the CPU writes
//        //   to another. Anchor uniforms should be specified with a max instance count for instancing.
//        //   Also uniform storage must be aligned (to 256 bytes) to meet the requirements to be an
//        //   argument in the constant address space of our shading functions.
//        let sharedUniformBufferSize = kAlignedSharedUniformsSize * kMaxBuffersInFlight
//        let anchorUniformBufferSize = kAlignedInstanceUniformsSize * kMaxBuffersInFlight
//        
//        // Create and allocate our uniform buffer objects. Indicate shared storage so that both the
//        //   CPU can access the buffer
//        sharedUniformBuffer = device.makeBuffer(length: sharedUniformBufferSize, options: .storageModeShared)
//        sharedUniformBuffer.label = "SharedUniformBuffer"
//        
//        anchorUniformBuffer = device.makeBuffer(length: anchorUniformBufferSize, options: .storageModeShared)
//        anchorUniformBuffer.label = "AnchorUniformBuffer"
//        
//        // Create a vertex buffer with our image plane vertex data.
//        let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
//        imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
//        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
//        
//        // Load all the shader files with a metal file extension in the project
//        let defaultLibrary = device.makeDefaultLibrary()!
//        
//        let capturedImageVertexFunction = defaultLibrary.makeFunction(name: "capturedImageVertexTransform")!
//        let capturedImageFragmentFunction = defaultLibrary.makeFunction(name: "capturedImageFragmentShader")!
//        
//        // Create a vertex descriptor for our image plane vertex buffer
//        let imagePlaneVertexDescriptor = MTLVertexDescriptor()
//        
//        // Positions.
//        imagePlaneVertexDescriptor.attributes[0].format = .float2
//        imagePlaneVertexDescriptor.attributes[0].offset = 0
//        imagePlaneVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
//        
//        // Texture coordinates.
//        imagePlaneVertexDescriptor.attributes[1].format = .float2
//        imagePlaneVertexDescriptor.attributes[1].offset = 8
//        imagePlaneVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
//        
//        // Buffer Layout
//        imagePlaneVertexDescriptor.layouts[0].stride = 16
//        imagePlaneVertexDescriptor.layouts[0].stepRate = 1
//        imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex
//        
//        // Create a pipeline state for rendering the captured image
//        let capturedImagePipelineStateDescriptor = MTLRenderPipelineDescriptor()
//        capturedImagePipelineStateDescriptor.label = "MyCapturedImagePipeline"
//        capturedImagePipelineStateDescriptor.sampleCount = renderDestination.sampleCount
//        capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction
//        capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction
//        capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
//        capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
//        capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
//        capturedImagePipelineStateDescriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
//        
//        do {
//            try capturedImagePipelineState = device.makeRenderPipelineState(descriptor: capturedImagePipelineStateDescriptor)
//        } catch let error {
//            print("Failed to created captured image pipeline state, error \(error)")
//        }
//        
//        let capturedImageDepthStateDescriptor = MTLDepthStencilDescriptor()
//        capturedImageDepthStateDescriptor.depthCompareFunction = .always
//        capturedImageDepthStateDescriptor.isDepthWriteEnabled = false
//        capturedImageDepthState = device.makeDepthStencilState(descriptor: capturedImageDepthStateDescriptor)
//        
//        // Create captured image texture cache
//        var textureCache: CVMetalTextureCache?
//        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
//        capturedImageTextureCache = textureCache
//        
//        let anchorGeometryVertexFunction = defaultLibrary.makeFunction(name: "anchorGeometryVertexTransform")!
//        let anchorGeometryFragmentFunction = defaultLibrary.makeFunction(name: "anchorGeometryFragmentLighting")!
//        
//        // Create a vertex descriptor for our Metal pipeline. Specifies the layout of vertices the
//        //   pipeline should expect. The layout below keeps attributes used to calculate vertex shader
//        //   output position separate (world position, skinning, tweening weights) separate from other
//        //   attributes (texture coordinates, normals).  This generally maximizes pipeline efficiency
//        geometryVertexDescriptor = MTLVertexDescriptor()
//        
//        // Positions.
//        geometryVertexDescriptor.attributes[0].format = .float3
//        geometryVertexDescriptor.attributes[0].offset = 0
//        geometryVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
//        
//        // Texture coordinates.
//        geometryVertexDescriptor.attributes[1].format = .float2
//        geometryVertexDescriptor.attributes[1].offset = 0
//        geometryVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshGenerics.rawValue)
//        
//        // Normals.
//        geometryVertexDescriptor.attributes[2].format = .half3
//        geometryVertexDescriptor.attributes[2].offset = 8
//        geometryVertexDescriptor.attributes[2].bufferIndex = Int(kBufferIndexMeshGenerics.rawValue)
//        
//        // Position Buffer Layout
//        geometryVertexDescriptor.layouts[0].stride = 12
//        geometryVertexDescriptor.layouts[0].stepRate = 1
//        geometryVertexDescriptor.layouts[0].stepFunction = .perVertex
//        
//        // Generic Attribute Buffer Layout
//        geometryVertexDescriptor.layouts[1].stride = 16
//        geometryVertexDescriptor.layouts[1].stepRate = 1
//        geometryVertexDescriptor.layouts[1].stepFunction = .perVertex
//        
//        // Create a reusable pipeline state for rendering anchor geometry
//        let anchorPipelineStateDescriptor = MTLRenderPipelineDescriptor()
//        anchorPipelineStateDescriptor.label = "MyAnchorPipeline"
//        anchorPipelineStateDescriptor.sampleCount = renderDestination.sampleCount
//        anchorPipelineStateDescriptor.vertexFunction = anchorGeometryVertexFunction
//        anchorPipelineStateDescriptor.fragmentFunction = anchorGeometryFragmentFunction
//        anchorPipelineStateDescriptor.vertexDescriptor = geometryVertexDescriptor
//        anchorPipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
//        anchorPipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
//        anchorPipelineStateDescriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
//        
//        do {
//            try anchorPipelineState = device.makeRenderPipelineState(descriptor: anchorPipelineStateDescriptor)
//        } catch let error {
//            print("Failed to created anchor geometry pipeline state, error \(error)")
//        }
//        
//        let anchorDepthStateDescriptor = MTLDepthStencilDescriptor()
//        anchorDepthStateDescriptor.depthCompareFunction = .less
//        anchorDepthStateDescriptor.isDepthWriteEnabled = true
//        anchorDepthState = device.makeDepthStencilState(descriptor: anchorDepthStateDescriptor)
//        
//        // Create the command queue
//        commandQueue = device.makeCommandQueue()
//    }
//    
//    func getEmptyMTLTexture() -> MTLTexture? {
//        
//        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
//            pixelFormat: MTLPixelFormat.rgba8Unorm,
//            width: width,
//            height: height,
//            mipmapped: false)
//        
//        textureDescriptor.usage = [.shaderRead, .shaderWrite]
//        
//        return self.device.makeTexture(descriptor: textureDescriptor)
//    }
//    
//}
