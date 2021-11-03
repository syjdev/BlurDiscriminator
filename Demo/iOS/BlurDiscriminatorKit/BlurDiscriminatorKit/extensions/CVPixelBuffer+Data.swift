//
//  CVPixelBuffer+Data.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/07.
//

import CoreVideo
import Accelerate


extension CVPixelBuffer {
    func makeData(byteCount: Int) -> Data? {
        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer {
          CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        guard let sourceData = CVPixelBufferGetBaseAddress(self) else {
          return nil
        }
        
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let destinationChannelCount = 3
        let destinationBytesPerRow = destinationChannelCount * width
        
        var sourceBuffer = vImage_Buffer(data: sourceData,
                                         height: vImagePixelCount(height),
                                         width: vImagePixelCount(width),
                                         rowBytes: sourceBytesPerRow)
        
        guard let destinationData = malloc(height * destinationBytesPerRow) else {
          return nil
        }
        
        defer {
            free(destinationData)
        }

        var destinationBuffer = vImage_Buffer(data: destinationData,
                                              height: vImagePixelCount(height),
                                              width: vImagePixelCount(width),
                                              rowBytes: destinationBytesPerRow)

        let pixelBufferFormat = CVPixelBufferGetPixelFormatType(self)

        switch (pixelBufferFormat) {
        case kCVPixelFormatType_32BGRA:
            vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, vImage_Flags(UInt8(kvImageNoFlags)))
        case kCVPixelFormatType_32ARGB:
            vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, vImage_Flags(UInt8(kvImageNoFlags)))
        case kCVPixelFormatType_32RGBA:
            vImageConvert_RGBA8888toRGB888(&sourceBuffer, &destinationBuffer, vImage_Flags(UInt8(kvImageNoFlags)))
        default:
            // Unknown pixel format.
            return nil
        }

        return Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
      }
}
