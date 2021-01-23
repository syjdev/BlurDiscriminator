//
//  BlurDiscriminator.swift
//  BlurDiscriminator-iOS
//
//  Created by syjdev on 2021/01/23.
//

import Metal
import MetalPerformanceShaders
import MetalKit


class BlurDiscriminator {
    
    let mtlDevice: MTLDevice
    let library: MTLLibrary
    var commandQueue: MTLCommandQueue?
    let computePipelineState: MTLComputePipelineState

    init() throws {
        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            throw BlurDiscriminatorError.mtlDeviceWasCorrupted
        }
        
        guard MPSSupportsMTLDevice(mtlDevice) else {
            throw BlurDiscriminatorError.unsupportedDevice
        }
        
        self.mtlDevice = mtlDevice
        self.commandQueue = self.mtlDevice.makeCommandQueue()

        do {
            self.library = try self.mtlDevice.makeLibrary(source: shaderFunction, options: nil)
        } catch {
            throw error
        }
        
        guard let kernelFunction = self.library.makeFunction(name: "changeToGrayscale") else {
            throw BlurDiscriminatorError.unsupportedDevice
        }
        
        self.computePipelineState = try self.mtlDevice.makeComputePipelineState(function: kernelFunction)
    }

    func calculateGrayscaledPixelVariance(cgImage: CGImage) -> Result<Float, Error> {
        if self.commandQueue == nil {
            self.commandQueue = self.mtlDevice.makeCommandQueue()
        }
        
        guard let commandQueue = self.commandQueue,
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return .failure(BlurDiscriminatorError.commandWasCorrupted)
        }

        let textureLoader = MTKTextureLoader(device: self.mtlDevice)
        let texture: MTLTexture
        do {
            texture = try textureLoader.newTexture(cgImage: cgImage, options: nil)
        } catch {
            return .failure(BlurDiscriminatorError.failedToMakeTexture)
        }

        let imageDescriptor = MPSImageDescriptor(channelFormat: .float32, width: cgImage.width, height: cgImage.height, featureChannels: 1)
        let inputImage = MPSImage(texture: texture, featureChannels: 3)
        let grayscaledImage = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: imageDescriptor)

        commandEncoder.setComputePipelineState(self.computePipelineState)
        commandEncoder.setTexture(inputImage.texture, index: 0)
        commandEncoder.setTexture(grayscaledImage.texture, index: 1)

        commandEncoder.dispatchThreadgroups(texture: texture, computePipelineState: self.computePipelineState)
        commandEncoder.endEncoding()

        let laplacian = MPSImageLaplacian(device: self.mtlDevice)
        let laplacianImage = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: imageDescriptor)
        laplacian.encode(commandBuffer: commandBuffer, sourceImage: grayscaledImage, destinationImage: laplacianImage)

        let imageStatisticsMeanAndVariance = MPSImageStatisticsMeanAndVariance(device: self.mtlDevice)
        let varianceDescriptor = MPSImageDescriptor(channelFormat: .float32, width: 2, height: 1, featureChannels: 1)
        let statisticsImage = MPSImage(device: self.mtlDevice, imageDescriptor: varianceDescriptor)
        imageStatisticsMeanAndVariance.encode(commandBuffer: commandBuffer, sourceImage: laplacianImage, destinationImage: statisticsImage)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        var variance: Float = 0
        statisticsImage.texture.getBytes(
            &variance,
            bytesPerRow: statisticsImage.texture.width * MemoryLayout<Float>.size,
            from: MTLRegionMake2D(1, 0, 1, 1),
            mipmapLevel: 0
        )

        return .success(variance)
    }
}
