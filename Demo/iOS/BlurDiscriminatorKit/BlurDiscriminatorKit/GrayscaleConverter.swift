//
//  GrayscaleConverter.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/11/03.
//

import Foundation
import Accelerate


internal final class GrayscaleConverter: OutputConverter {
    private let inputWidth: Int
    private let inputHeight: Int
    private let grayscaleImageFormat: vImage_CGImageFormat
    
    private var preBias: [Int16] = [0, 0, 0]
    private var postBias: Int32 = 0
    private var coefficientsMatrix: [Int16] = [
        Int16(1 * 0x100),
        Int16(1 * 0x100),
        Int16(1 * 0x100)
    ]
    
    
    internal init(inputWidth: Int, inputHeight: Int) {
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
        
        let imageFormat =  vImage_CGImageFormat(bitsPerComponent: 8,
                                                bitsPerPixel: 8,
                                                colorSpace: CGColorSpaceCreateDeviceGray(),
                                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                                renderingIntent: .defaultIntent)
        
        guard let imageFormat = imageFormat else { fatalError() }
        self.grayscaleImageFormat = imageFormat
    }
    
    
    internal func convert(data: Data) -> BlurObservation? {
        var mutableData = data
        let imageBuffer = mutableData.withUnsafeMutableBytes({ (rawBufferPointer) -> vImage_Buffer? in
            var sourceBuffer = vImage_Buffer(data: rawBufferPointer.baseAddress,
                                             height: vImagePixelCount(inputWidth),
                                             width: vImagePixelCount(inputHeight),
                                             rowBytes: inputWidth)
            let sourceBufferPointer = withUnsafePointer(to: &sourceBuffer) {
                return $0
            }

            var destinationBuffer: vImage_Buffer
            do {
                destinationBuffer = try vImage_Buffer(width: inputWidth, height: inputHeight, bitsPerPixel: 8)
            } catch {
                return nil
            }

            let destinationBufferPointer = withUnsafePointer(to: &destinationBuffer) {
                return $0
            }

            var sources: UnsafePointer<vImage_Buffer>? = sourceBufferPointer
            var destinations: UnsafePointer<vImage_Buffer>? = destinationBufferPointer

            vImageMatrixMultiply_Planar8(&sources,
                                         &destinations,
                                         1,
                                         1,
                                         &coefficientsMatrix,
                                         0x100,
                                         &preBias,
                                         &postBias,
                                         vImage_Flags(kvImageNoFlags))
            
            return destinationBuffer
        })
        
        guard let imageBuffer = imageBuffer else { return nil }
        return self.makeBlurObservation(imageBuffer: imageBuffer)
    }
    
    
    internal func makeBlurObservation(imageBuffer: vImage_Buffer) -> BlurObservation? {
        let blurMap: CGImage
        do {
            blurMap = try imageBuffer.createCGImage(format: grayscaleImageFormat)
        } catch {
            return nil
        }

        guard let blurData = blurMap.dataProvider?.data else { return nil }
        let blurDataBufferPointer = UnsafeBufferPointer(start: CFDataGetBytePtr(blurData),
                                                        count: inputWidth * inputHeight)
        return BlurObservation(blurMap: blurMap, grayscaledPixels: Array(blurDataBufferPointer))
    }
}
