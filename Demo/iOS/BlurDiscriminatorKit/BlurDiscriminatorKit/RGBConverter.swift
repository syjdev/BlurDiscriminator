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
        guard let context = cgImage.makeAspectFitPaddedContext(width: inputWidth, height: inputHeight),
              let baseAddress = context.data
        else {
            return nil
        }

        var sourceBuffer = vImage_Buffer(data: baseAddress,
                                         height: vImagePixelCount(inputHeight),
                                         width: vImagePixelCount(inputWidth),
                                         rowBytes: context.bytesPerRow)

        // The uint8 model quantizes the input with scale 1/255 and zero point 0,
        // so raw pixel values are already the quantized representation.
        var pixelData = [UInt8](repeating: 0, count: inputWidth * inputHeight * 3)
        let conversionError = pixelData.withUnsafeMutableBytes { rawBufferPointer -> vImage_Error in
            var destinationBuffer = vImage_Buffer(data: rawBufferPointer.baseAddress,
                                                  height: vImagePixelCount(inputHeight),
                                                  width: vImagePixelCount(inputWidth),
                                                  rowBytes: inputWidth * 3)
            return vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, vImage_Flags(kvImageNoFlags))
        }

        guard conversionError == kvImageNoError else { return nil }

        return Data(pixelData)
    }
}
