//
//  CGImage+makePixelBuffer.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/07.
//

import CoreGraphics
import CoreVideo
import Accelerate


extension CGImage {
    func makePixelBuffer() -> CVPixelBuffer? {
        var optionalPixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                          kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         self.width,
                                         self.height,
                                         kCVPixelFormatType_32BGRA,
                                         attributes as CFDictionary,
                                         &optionalPixelBuffer)

        guard status == kCVReturnSuccess, let pixelBuffer = optionalPixelBuffer else { return nil }
        
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard CVPixelBufferLockBaseAddress(pixelBuffer, flags) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                      width: self.width,
                                      height: self.height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo.rawValue)
        else {
            return nil
        }
        
        context.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        
        return pixelBuffer
    }
}
