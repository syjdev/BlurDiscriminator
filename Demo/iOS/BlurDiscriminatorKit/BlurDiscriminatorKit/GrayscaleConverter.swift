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

    internal init(inputWidth: Int, inputHeight: Int) {
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
        
        let bitmapInfo = CGBitmapInfo(
            rawValue: kCGBitmapByteOrder32Host.rawValue |
            CGBitmapInfo.floatComponents.rawValue)
        let imageFormat = vImage_CGImageFormat(bitsPerComponent: 32,
                                               bitsPerPixel: 32,
                                               colorSpace: CGColorSpaceCreateDeviceGray(),
                                               bitmapInfo: bitmapInfo)!

        self.grayscaleImageFormat = imageFormat
    }
    
    func convert(data: Data, originImageWidth: Int, originImageHeight: Int) -> BlurObservation? {
        var mutableData = data

        let imageBuffer = mutableData.withUnsafeMutableBytes({ (rawBufferPointer) -> vImage_Buffer? in
            let sourceBuffer = vImage_Buffer(data: rawBufferPointer.baseAddress,
                                             height: vImagePixelCount(inputWidth),
                                             width: vImagePixelCount(inputHeight),
                                             rowBytes: inputWidth * 4)

            
            return sourceBuffer
        })
        
        guard let imageBuffer = imageBuffer, let grayscaledImage = self.makeGrayscaleImage(imageBuffer: imageBuffer) else { return nil }
        
        let paddingRemovedImage: CGImage?
        if (originImageWidth > originImageHeight) {
            let adjustHeight = Int(Float(inputHeight) * Float(originImageHeight) / Float(originImageWidth))
            paddingRemovedImage = grayscaledImage.cropCGImage(width: inputWidth, height: adjustHeight)
        } else if (originImageWidth < originImageHeight) {
            let adjustWidth = Int(Float(inputWidth) * Float(originImageWidth) / Float(originImageHeight))
            paddingRemovedImage = grayscaledImage.cropCGImage(width: adjustWidth, height: inputHeight)
        } else {
            paddingRemovedImage = grayscaledImage
        }
        
        guard let paddingRemovedImage = paddingRemovedImage, let cfData = paddingRemovedImage.dataProvider?.data else {
            fatalError()
        }

        let blurDataBufferPointer = UnsafeBufferPointer(start: CFDataGetBytePtr(cfData),
                                                        count: inputWidth * inputHeight)

        
        return BlurObservation(blurMap: paddingRemovedImage, grayscaledPixels: Array(blurDataBufferPointer))
    }

    internal func makeGrayscaleImage(imageBuffer: vImage_Buffer) -> CGImage? {
        var error: vImage_Error = kvImageNoError
        var sourceBuffer = imageBuffer
        
        guard let cgImage = vImageCreateCGImageFromBuffer(&sourceBuffer, &grayscaleImageFormat, nil, nil, vImage_Flags(kvImageNoFlags), &error)?.takeRetainedValue(),
              error == kvImageNoError
        else {
            print("Error in creating CGImage: \(error)")
            return nil
        }

        return cgImage
    }
}

private extension CGImage {
    func cropCGImage(width: Int, height: Int) -> CGImage? {
        let cropRect = CGRect(x: 0, y: 0, width: width, height: height)
        
        guard let croppedImage = self.cropping(to: cropRect) else {
            return nil
        }
        
        return croppedImage
    }
}
