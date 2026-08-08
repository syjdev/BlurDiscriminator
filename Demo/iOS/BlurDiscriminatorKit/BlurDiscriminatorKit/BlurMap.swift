// SPDX-License-Identifier: Apache-2.0
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


internal enum BlurMapGeometry {
    /// The un-padded region of a letterboxed square output, matching the original image's aspect
    /// ratio. Mirrors the top-left aspect-fit placement used by ``CGImage/makeAspectFitPadded(width:height:)``,
    /// so the returned size is the slice of the model output that corresponds to real image content.
    static func croppedSize(outputWidth: Int, outputHeight: Int,
                            originalWidth: Int, originalHeight: Int) -> (width: Int, height: Int) {
        guard originalWidth > 0, originalHeight > 0 else { return (outputWidth, outputHeight) }

        if originalWidth > originalHeight {
            return (outputWidth, Int(Float(outputHeight) * Float(originalHeight) / Float(originalWidth)))
        } else if originalWidth < originalHeight {
            return (Int(Float(outputWidth) * Float(originalWidth) / Float(originalHeight)), outputHeight)
        } else {
            return (outputWidth, outputHeight)
        }
    }

    /// Crops the top-left `cropWidth`×`cropHeight` block out of a row-major, `sourceWidth`-wide map.
    static func cropTopLeft(_ pixels: [UInt8], sourceWidth: Int,
                            cropWidth: Int, cropHeight: Int) -> [UInt8] {
        guard sourceWidth > 0 else { return pixels }
        let sourceHeight = pixels.count / sourceWidth
        guard cropWidth < sourceWidth || cropHeight < sourceHeight else { return pixels }

        var cropped = [UInt8]()
        cropped.reserveCapacity(cropWidth * cropHeight)
        for row in 0 ..< cropHeight {
            let start = row * sourceWidth
            cropped.append(contentsOf: pixels[start ..< start + cropWidth])
        }
        return cropped
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
