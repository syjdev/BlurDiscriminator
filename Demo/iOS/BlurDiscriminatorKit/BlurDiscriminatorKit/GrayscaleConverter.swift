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
    private var grayscaleImageFormat: vImage_CGImageFormat
    
    
    let divisor: Int32 = 0x1000
    private var preBias: [Int16] = [0, 0, 0]
    private var postBias: Int32 = 0
    private var coefficientsMatrix: [Int16] = [
        Int16(0.0722 * 0x1000),  // blue
        Int16(0.7152 * 0x1000),  // green
        Int16(0.2126 * 0x1000),  // red
    ]
    
    internal init(inputWidth: Int, inputHeight: Int) {
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
        
        let imageFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                               bitsPerPixel: 8,
                                               colorSpace: CGColorSpaceCreateDeviceGray(),
                                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                               renderingIntent: .defaultIntent)
        
        guard let imageFormat = imageFormat else { fatalError() }
        self.grayscaleImageFormat = imageFormat
    }
    
    
//    internal func convert(data: Data) -> BlurObservation? {
//        var mutableData = data
//        let imageBuffer = mutableData.withUnsafeMutableBytes({ (rawBufferPointer) -> vImage_Buffer? in
//            var sourceBuffer = vImage_Buffer(data: rawBufferPointer.baseAddress,
//                                             height: vImagePixelCount(inputWidth),
//                                             width: vImagePixelCount(inputHeight),
//                                             rowBytes: inputWidth * 4)
//            let sourceBufferPointer = withUnsafePointer(to: &sourceBuffer) {
//                return $0
//            }
//            
//            var destinationBuffer: vImage_Buffer
//            do {
//                destinationBuffer = try vImage_Buffer(width: inputWidth, height: inputHeight, bitsPerPixel: 8)
//            } catch {
//                return nil
//            }
//            
//            let destinationBufferPointer = withUnsafePointer(to: &destinationBuffer) {
//                return $0
//            }
//            
//            var sources: UnsafePointer<vImage_Buffer>? = sourceBufferPointer
//            var destinations: UnsafePointer<vImage_Buffer>? = destinationBufferPointer
//            
//            vImageMatrixMultiply_ARGB8888ToPlanar8(sources!,
//                                         destinations!,
//                                         &coefficientsMatrix,
//                                         divisor,
//                                         nil,
//                                         0,
//                                         vImage_Flags(kvImageNoFlags))
//            return destinationBuffer
//        })
//        
//        guard let imageBuffer = imageBuffer else { return nil }
//        return self.makeBlurObservation(imageBuffer: imageBuffer)
//    }
    
//    internal func convert(data: Data) -> BlurObservation? {
//        var mutableData = data
//        
////        var rearrangedData = Data(count: inputWidth * inputHeight * 4)
////            
////        // Rearrange the pixel data using vDSP functions
////        var srcStride = vDSP_Stride(4)
////        var destStride = vDSP_Stride(4)
////        vDSP_mtrans((mutableData.withUnsafeMutableBytes { $0.bindMemory(to: Float.self).baseAddress! }),
////                    srcStride,
////                    (rearrangedData.withUnsafeMutableBytes { $0.bindMemory(to: Float.self).baseAddress! }),
////                    destStride,
////                    vDSP_Length(inputWidth),
////                    vDSP_Length(inputHeight))
//        
//        
//        
//        let imageBuffer = mutableData.withUnsafeMutableBytes({ (rawBufferPointer) -> vImage_Buffer? in
//            var sourceBuffer = vImage_Buffer(data: rawBufferPointer.baseAddress,
//                                             height: vImagePixelCount(inputWidth),
//                                             width: vImagePixelCount(inputHeight),
//                                             rowBytes: inputWidth * 4)
//            let sourceBufferPointer = withUnsafePointer(to: &sourceBuffer) {
//                return $0
//            }
//            
//            var destinationBuffer: vImage_Buffer
//            do {
//                destinationBuffer = try vImage_Buffer(width: inputWidth, height: inputHeight, bitsPerPixel: 8)
//            } catch {
//                return nil
//            }
//            
//            let destinationBufferPointer = withUnsafePointer(to: &destinationBuffer) {
//                return $0
//            }
//            
//            let sources: UnsafePointer<vImage_Buffer>? = sourceBufferPointer
//            let destinations: UnsafePointer<vImage_Buffer>? = destinationBufferPointer
//            
//            vImageMatrixMultiply_ARGB8888ToPlanar8(sources!,
//                                         destinations!,
//                                         &coefficientsMatrix,
//                                         divisor,
//                                         nil,
//                                         0,
//                                         vImage_Flags(kvImageNoFlags))
//            
//            var transposedBuffer: vImage_Buffer
//            do {
//                transposedBuffer = try vImage_Buffer(width: inputWidth, height: inputHeight, bitsPerPixel: 8)
//            } catch {
//                return nil
//            }
//            
//            for y in 0..<Int(destinationBuffer.height) {
//                for x in 0..<Int(destinationBuffer.width) {
//                    let sourceIndex = y * destinationBuffer.rowBytes + x
//                    let destIndex = x * transposedBuffer.rowBytes + y
//                    transposedBuffer.data.advanced(by: destIndex).assumingMemoryBound(to: UInt8.self).pointee = destinationBuffer.data.advanced(by: sourceIndex).assumingMemoryBound(to: UInt8.self).pointee
////                    for i in 0..<1 {
////                        transposedBuffer.data.advanced(by: destIndex + i).assumingMemoryBound(to: UInt8.self).pointee = destinationBuffer.data.advanced(by: sourceIndex + i).assumingMemoryBound(to: UInt8.self).pointee
////                    }
//                }
//            }
//            
////            let threshold = 125
////            
////            var table: [UInt8] = Array(repeating: 0, count: inputWidth)
////            for _ in threshold..<inputWidth {
////                    table.append(1)
////                }
////                for _ in threshold...255 {
////                    table.append(1)
////                }
//            
////            vImageTableLookUp_Planar8(&transposedBuffer, &transposedBuffer, &table, vImage_Flags(kvImageNoFlags))
//            
//
//            return transposedBuffer
//        })
//        
//        guard let imageBuffer = imageBuffer else { return nil }
//        return self.makeBlurObservation(imageBuffer: imageBuffer)
//    }
    
    internal func convert(data: Data) -> BlurObservation? {
        var mutableData = data
        
//        var rearrangedData = Data(count: inputWidth * inputHeight * 4)
//
//        // Rearrange the pixel data using vDSP functions
//        var srcStride = vDSP_Stride(4)
//        var destStride = vDSP_Stride(4)
//        vDSP_mtrans((mutableData.withUnsafeMutableBytes { $0.bindMemory(to: Float.self).baseAddress! }),
//                    srcStride,
//                    (rearrangedData.withUnsafeMutableBytes { $0.bindMemory(to: Float.self).baseAddress! }),
//                    destStride,
//                    vDSP_Length(inputWidth),
//                    vDSP_Length(inputHeight))
        
        
        
        let imageBuffer = mutableData.withUnsafeMutableBytes({ (rawBufferPointer) -> vImage_Buffer? in
            var sourceBuffer = vImage_Buffer(data: rawBufferPointer.baseAddress,
                                             height: vImagePixelCount(inputWidth),
                                             width: vImagePixelCount(inputHeight),
                                             rowBytes: inputWidth * 4)

            
            return sourceBuffer
        })
        
        guard let imageBuffer = imageBuffer else { return nil }
        return self.makeBlurObservation(imageBuffer: imageBuffer)
    }

    internal func makeBlurObservation(imageBuffer: vImage_Buffer) -> BlurObservation? {
        defer {
//            imageBuffer.free()
        }

        let bitmapInfo = CGBitmapInfo(
            rawValue: kCGBitmapByteOrder32Host.rawValue |
            CGBitmapInfo.floatComponents.rawValue)

        var format = vImage_CGImageFormat(bitsPerComponent: 32,
                                          bitsPerPixel: 32,
                                          colorSpace: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: bitmapInfo)!
        
        
        
        // vImageMatrixMultiply_ARGB8888ToPlanar8는 column-major로 바꿔버리는 것 같으니 transpose 필요
        // color threshold를 이용하여 완전한 black / white 분할 가능할듯
        
        var error: vImage_Error = kvImageNoError
            var sourceBuffer = imageBuffer
            
            guard let cgImage = vImageCreateCGImageFromBuffer(&sourceBuffer, &format, nil, nil, vImage_Flags(kvImageNoFlags), &error)?.takeRetainedValue(),
                  error == kvImageNoError else {
                print("Error in creating CGImage: \(error)")
                return nil
            }
        
        return BlurObservation(blurMap: cgImage, grayscaledPixels: [])
    }
}
