//
//  RGBConverter.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/06.
//

import Foundation
import CoreGraphics
import Accelerate


internal final class RGBConverter: InputConverter {
    private let inputWidth: Int
    private let inputHeight: Int
    
    
    internal init(inputWidth: Int, inputHeight: Int) {
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
    }
    
    
    internal func convert(cgImage: CGImage) -> Data? {
        guard let resized = cgImage.resizeWithPadding(width: inputWidth, height: inputHeight),
              let data = new_makeData(image: resized)
        else {
            return nil
        }
        
        return data
    }
    
    private func new_makeData(image: CGImage) -> Data? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        guard let imageData = context.data else { return nil }

        let width = context.width
        let height = context.height

        // 이미지 데이터를 vImage_Buffer로 설정
        var sourceBuffer = vImage_Buffer(
            data: imageData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: context.bytesPerRow
        )
        
        // 플래너 포맷으로 데이터 저장할 버퍼 생성
        var destinationA = [UInt8](repeating: 0, count: width * height)
        var destinationR = [UInt8](repeating: 0, count: width * height)
        var destinationG = [UInt8](repeating: 0, count: width * height)
        var destinationB = [UInt8](repeating: 0, count: width * height)
        
        let destinationPlanarBuffers: [vImage_Buffer] = [
            destinationA.withUnsafeMutableBufferPointer { bufferPointer in
                return vImage_Buffer(data: bufferPointer.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
            },
            destinationR.withUnsafeMutableBufferPointer { bufferPointer in
                return vImage_Buffer(data: bufferPointer.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
            },
            destinationG.withUnsafeMutableBufferPointer { bufferPointer in
                return vImage_Buffer(data: bufferPointer.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
            },
            destinationB.withUnsafeMutableBufferPointer { bufferPointer in
                return vImage_Buffer(data: bufferPointer.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
            }
        ]
        
        var planarDest: [vImage_Buffer] = [
            destinationPlanarBuffers[0],
            destinationPlanarBuffers[1],
            destinationPlanarBuffers[2],
            destinationPlanarBuffers[3]
        ]
        
        // ARGB8888을 Planar8로 변환
        let result = vImageConvert_ARGB8888toPlanar8(&sourceBuffer, &planarDest[0], &planarDest[1], &planarDest[2], &planarDest[3], vImage_Flags(kvImageNoFlags))
        
        guard result == kvImageNoError else {
            return nil
        }
        
        let totalElements = width * height * 3

        var normalizedData = [Float32](repeating: 0, count: totalElements)
        
    //    var inputData = Data()
        
        for i in 0..<(width * height) {
            normalizedData[3 * i] = (Float32(destinationR[i]) / 255.0)
            normalizedData[3 * i + 1] = (Float32(destinationG[i]) / 255.0)
            normalizedData[3 * i + 2] = (Float32(destinationB[i]) / 255.0)
            
    //        var normalizedRed = Float32(destinationR[i]) / 255.0
    //        var normalizedGreen = Float32(destinationG[i]) / 255.0
    //        var normalizedBlue = Float32(destinationB[i]) / 255.0
    //
    //        let elementSize = MemoryLayout.size(ofValue: normalizedRed)
    //        var bytes = [UInt8](repeating: 0, count: elementSize)
    //
    //        memcpy(&bytes, &normalizedRed, elementSize)
    //        wowData.append(&bytes, count: elementSize)
    //        memcpy(&bytes, &normalizedGreen, elementSize)
    //        wowData.append(&bytes, count: elementSize)
    //        memcpy(&bytes, &normalizedBlue, elementSize)
    //        wowData.append(&bytes, count: elementSize)
            
        }
        
        let data = normalizedData.withUnsafeBufferPointer { bufferPointer in
            return Data(buffer: bufferPointer)
        }
        
        return data
    }
}
