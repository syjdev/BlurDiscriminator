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
    
    internal func convert(data: Data) -> BlurObservation? {
        var mutableData = data

        let imageBuffer = mutableData.withUnsafeMutableBytes({ (rawBufferPointer) -> vImage_Buffer? in
            let sourceBuffer = vImage_Buffer(data: rawBufferPointer.baseAddress,
                                             height: vImagePixelCount(inputWidth),
                                             width: vImagePixelCount(inputHeight),
                                             rowBytes: inputWidth * 4)

            
            return sourceBuffer
        })
        
        guard let imageBuffer = imageBuffer else { return nil }
        return self.makeBlurObservation(imageBuffer: imageBuffer)
    }

    internal func makeBlurObservation(imageBuffer: vImage_Buffer) -> BlurObservation? {
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
              error == kvImageNoError,
        let cfData = cgImage.dataProvider?.data else {
            print("Error in creating CGImage: \(error)")
            return nil
        }

        let blurDataBufferPointer = UnsafeBufferPointer(start: CFDataGetBytePtr(cfData),
                                                        count: inputWidth * inputHeight)
        
        return BlurObservation(blurMap: cgImage, grayscaledPixels: Array(blurDataBufferPointer))
    }
}
