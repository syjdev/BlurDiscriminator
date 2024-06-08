//
//  BlurDiscriminator.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/23.
//

import Foundation
import CoreGraphics
import Accelerate
import BlurDiscriminatorKit.Private

public final class BlurDiscriminator {
    private let _interpreter: InterpreterWrapper
    private let inputConverter: InputConverter = RGBConverter(inputWidth: Constants.inputWidth,
                                                              inputHeight: Constants.inputHeight)
    private let outputConverter: OutputConverter = GrayscaleConverter(inputWidth: Constants.inputWidth,
                                                                      inputHeight: Constants.inputHeight)
    
    public init(modelPath: String, numberOfThread: UInt8) {
        _interpreter = InterpreterWrapper(modelPath: modelPath, andNumberOfThread: numberOfThread)
    }
    
    
    public func predict(input: CGImage) -> BlurObservation? {
        guard let outputData = self.interpret(input: input) else { return nil }

//        let cgImage = createCGImage(from: outputData, width: 224, height: 224)
        
        return self.outputConverter.convert(data: outputData)
    }

    internal func interpret(input: CGImage) -> Data? {
        guard let awesomeDate = new_makeData(image: input) else {
            return nil
        }
        
        return _interpreter.interpret(withInputData: awesomeDate)
    }
}

private func makeData(image: CGImage) -> Data? {
    guard let context = CGContext(
      data: nil,
      width: image.width, height: image.height,
      bitsPerComponent: 8, bytesPerRow: image.width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
    ) else {
      return nil
    }

    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let imageData = context.data else { return nil }

    var inputData = Data()
    for row in 0 ..< 224 {
        for col in 0 ..< 224 {
            let offset = 4 * (col * context.width + row)
            // (Ignore offset 0, the unused alpha channel)
            let red = imageData.load(fromByteOffset: offset + 1, as: UInt8.self)
            let green = imageData.load(fromByteOffset: offset + 2, as: UInt8.self)
            let blue = imageData.load(fromByteOffset: offset + 3, as: UInt8.self)
            
            // Normalize channel values to [0.0, 1.0]. This requirement varies
            // by model. For example, some models might require values to be
            // normalized to the range [-1.0, 1.0] instead, and others might
            // require fixed-point values or the original bytes.
            var normalizedRed = Float32(red) / 255.0
            var normalizedGreen = Float32(green) / 255.0
            var normalizedBlue = Float32(blue) / 255.0
            
            // Append normalized values to Data object in RGB order.
            let elementSize = MemoryLayout.size(ofValue: normalizedRed)
            var bytes = [UInt8](repeating: 0, count: elementSize)
            memcpy(&bytes, &normalizedRed, elementSize)
            inputData.append(&bytes, count: elementSize)
            memcpy(&bytes, &normalizedGreen, elementSize)
            inputData.append(&bytes, count: elementSize)
            memcpy(&bytes, &normalizedBlue, elementSize)
            inputData.append(&bytes, count: elementSize)
        }
    }
    
    return inputData
}


func createCGImage(from floatData: Data, width: Int, height: Int) -> CGImage? {
    // Create a bitmap context
    let bitmapInfo = CGBitmapInfo(
        rawValue: kCGBitmapByteOrder32Host.rawValue |
        CGBitmapInfo.floatComponents.rawValue)
    
    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 32,
                                  bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: bitmapInfo.rawValue) else {
        return nil
    }
    
    let totalPixels = width * height
    
    // Calculate the size of each pixel value (assuming each pixel value is a Float)
    let pixelSize = MemoryLayout<Float>.size
    
    // Create a temporary buffer to hold rearranged pixel data
    var rearrangedData = Data(count: totalPixels * pixelSize)
    
    for row in 0..<height {
        for col in 0..<width {
            let pixelIndex = row * width + col
            let rearrangedIndex = col * height + row
            let pixelRange = pixelIndex * pixelSize..<pixelIndex * pixelSize + pixelSize
            let rearrangedRange = rearrangedIndex * pixelSize..<rearrangedIndex * pixelSize + pixelSize
            rearrangedData.replaceSubrange(rearrangedRange, with: floatData[pixelRange])
        }
    }
    
    // Set the float data to the context
    rearrangedData.withUnsafeBytes { dataBytes in
        guard let baseAddress = dataBytes.baseAddress else { return }
        let rawData = UnsafeMutableRawPointer(mutating: baseAddress)
        let dataLength = floatData.count
        context.data?.copyMemory(from: rawData, byteCount: dataLength)
    }
    
    // Create a CGImage from the context
    guard let cgImage = context.makeImage() else {
        return nil
    }
    
    return cgImage
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
    
    var destinationPlanarBuffers: [vImage_Buffer] = [
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
