//
//  BlurMap.swift
//  BlurDiscriminatorKit
//
//  Helpers that turn the Core ML sigmoid output into an 8-bit grayscale blur map.
//

import Accelerate
import CoreGraphics
import Foundation


internal enum PixelConverter {
    /// Converts a float sigmoid buffer in [0, 1] to UInt8 [0, 255] with vDSP:
    /// scale by 255, clip to the valid range, then round-to-nearest into UInt8.
    /// Replaces per-pixel `UInt8(max(0, min(255, v * 255)))` loops.
    static func floatToUInt8<Buffer: AccelerateBuffer>(_ source: Buffer) -> [UInt8] where Buffer.Element == Float {
        let scaled = vDSP.clip(vDSP.multiply(255, source), to: 0 ... 255)

        var pixels = [UInt8](repeating: 0, count: scaled.count)
        vDSP.convertElements(of: scaled, to: &pixels, rounding: .towardNearestInteger)
        return pixels
    }
}


internal enum BlurMapRenderer {
    /// Builds a grayscale CGImage from width×height UInt8 pixels in row-major order.
    static func makeBlurMap(grayscaledPixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, grayscaledPixels.count == width * height else { return nil }

        // Keep every use of the pixel buffer inside the closure: `makeImage()` copies the
        // bitmap, so the context never sees the pointer beyond this scope. (Passing `&pixels`
        // straight to `CGContext(data:)` would leave the context holding a pointer that is
        // only valid for the duration of the initializer call.)
        var pixels = grayscaledPixels
        return pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }

            return context.makeImage()
        }
    }
}
