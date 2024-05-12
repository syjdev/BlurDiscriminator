//
//  BlurDiscriminator.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/23.
//

import Foundation
import CoreGraphics
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
        
        
        let cgImage = createCGImage(from: outputData, width: 224, height: 224)
        
        return self.outputConverter.convert(data: outputData)
//        return BlurObservation(blurMap: convertToCGImage(data: outputData, width: 224, height: 224)!, grayscaledPixels: [])
//        return BlurObservation(blurMap: cgImage!, grayscaledPixels: [], data: outputData)
    }

    internal func interpret(input: CGImage) -> Data? {
        guard let convertedData = inputConverter.convert(cgImage: input), let awesomeDate = makeData(image: input) else {
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
          let red = imageData.load(fromByteOffset: offset+1, as: UInt8.self)
          let green = imageData.load(fromByteOffset: offset+2, as: UInt8.self)
          let blue = imageData.load(fromByteOffset: offset+3, as: UInt8.self)

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
    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
//                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGBitmapInfo(rawValue:  CGImageAlphaInfo.noneSkipLast.rawValue).rawValue) else {
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
    
//    floatData.withUnsafeBytes { dataBytes in
//            guard let baseAddress = dataBytes.baseAddress else { return }
//            let rawData = UnsafeMutableRawPointer(mutating: baseAddress).assumingMemoryBound(to: Float.self)
//            
//            for y in 0..<height {
//                for x in 0..<width {
//                    let pixelIndex = y * width + x
//                    let floatValue = rawData[pixelIndex]
//                    
//                    // Convert float value to UInt8 for each color channel
//                    let intValue = UInt8(floatValue * 255)
//                    
//                    // Set pixel color in the context (with transposed coordinates)
//                    context.setFillColor(red: CGFloat(intValue) / 255.0, green: CGFloat(intValue) / 255.0, blue: CGFloat(intValue) / 255.0, alpha: 1.0)
//                    context.fill(CGRect(x: y, y: width - x - 1, width: 1, height: 1))
//                }
//            }
//        }
        
    
    
    // Create a CGImage from the context
    guard let cgImage = context.makeImage() else {
        return nil
    }
    
    return cgImage
}


func createRGBData(from grayscaleData: Data, width: Int, height: Int) -> Data? {
    // Calculate the total number of pixels
    let totalPixels = width * height
    
    // Create a new data buffer to hold RGB values
    var rgbData = Data(count: totalPixels * 3)
    
    // Convert grayscale values to RGB
    grayscaleData.withUnsafeBytes { grayscaleBytes in
        guard let grayscalePointer = grayscaleBytes.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
        
        for pixelIndex in 0..<totalPixels {
            // Get grayscale value
            let grayscaleValue = grayscalePointer[pixelIndex]
            
            // Convert grayscale value to UInt8 for each color channel
            let intValue = UInt8(grayscaleValue * 255)
            
            // Assign the same value to R, G, B channels
            rgbData[pixelIndex * 3] = intValue  // R
            rgbData[pixelIndex * 3 + 1] = intValue  // G
            rgbData[pixelIndex * 3 + 2] = intValue  // B
        }
    }
    
    return rgbData
}



func createCGImageTest(from rgbData: Data, width: Int, height: Int) -> CGImage? {
    // Create a data provider from RGB data
    guard let dataProvider = CGDataProvider(data: rgbData as CFData) else { return nil }
    
    // Create a bitmap context
    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: width * 3,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue:  CGImageAlphaInfo.noneSkipLast.rawValue).rawValue) else {
        return nil
    }
    
    // Create a CGImage from the context
    guard let cgImage = CGImage(width: width,
                                 height: height,
                                 bitsPerComponent: 8,
                                 bitsPerPixel: 24,
                                 bytesPerRow: width * 3,
                                 space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGBitmapInfo(rawValue: 0),
                                 provider: dataProvider,
                                 decode: nil,
                                 shouldInterpolate: false,
                                 intent: .defaultIntent) else {
        return nil
    }
    
    return cgImage
}
