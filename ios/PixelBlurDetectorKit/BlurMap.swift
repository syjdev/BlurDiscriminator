// SPDX-License-Identifier: Apache-2.0
//
//  BlurMap.swift
//  PixelBlurDetectorKit
//
//  Helpers that turn the Core ML sigmoid output into an 8-bit grayscale blur map.
//

import Accelerate
import CoreGraphics
import CoreML
import Foundation


internal enum PixelConverter {
    /// Converts the top-left `width`×`height` block of a 1×H×W×1 sigmoid map in [0, 1] to UInt8
    /// [0, 255]: scale by 255, clip to the valid range, then round-to-nearest.
    ///
    /// The map is read through `multiArray.strides`, never assumed to be densely packed: Core ML
    /// may pad rows of GPU / Neural Engine outputs, and reading such a buffer as contiguous shears
    /// the blur map. Only the cropped block is converted, row by row with vDSP, straight into the
    /// result — no full-size intermediate arrays.
    static func grayscalePixels(from multiArray: MLMultiArray, width: Int, height: Int) throws -> [UInt8] {
        let shape = multiArray.shape.map { $0.intValue }
        let strides = multiArray.strides.map { $0.intValue }
        guard shape.count == 4, strides.count == 4,
              width > 0, height > 0, height <= shape[1], width <= shape[2] else {
            throw PixelBlurDetectorError.unexpectedOutput
        }
        let rowStride = strides[1]
        let columnStride = strides[2]
        let lastElement = (height - 1) * rowStride + (width - 1) * columnStride

        switch multiArray.dataType {
        case .float32:
            return try multiArray.withUnsafeBytes { raw in
                let floats = raw.bindMemory(to: Float.self)
                guard lastElement < floats.count, let base = floats.baseAddress else {
                    throw PixelBlurDetectorError.unexpectedOutput
                }
                return convert(base, rowStride: rowStride, columnStride: columnStride, width: width, height: height)
            }

        case .float16 where columnStride == 1:
            // Widen the cropped rows to Float32 with vImage, then reuse the Float path. (Swift's
            // `Float16` is unavailable on x86_64, so go through raw bytes + vImage.)
            var floats = [Float](repeating: 0, count: width * height)
            try multiArray.withUnsafeBytes { raw in
                guard (lastElement + 1) * MemoryLayout<UInt16>.stride <= raw.count else {
                    throw PixelBlurDetectorError.unexpectedOutput
                }
                var source = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: raw.baseAddress),
                                           height: vImagePixelCount(height),
                                           width: vImagePixelCount(width),
                                           rowBytes: rowStride * MemoryLayout<UInt16>.stride)
                let error = floats.withUnsafeMutableBytes { destinationRaw -> vImage_Error in
                    var destination = vImage_Buffer(data: destinationRaw.baseAddress,
                                                    height: vImagePixelCount(height),
                                                    width: vImagePixelCount(width),
                                                    rowBytes: width * MemoryLayout<Float>.stride)
                    return vImageConvert_Planar16FtoPlanarF(&source, &destination, vImage_Flags(kvImageNoFlags))
                }
                guard error == kvImageNoError else {
                    throw PixelBlurDetectorError.unexpectedOutput
                }
            }
            return floats.withUnsafeBufferPointer {
                convert($0.baseAddress!, rowStride: width, columnStride: 1, width: width, height: height)
            }

        default:
            // Rare fallback (e.g. .double, or a column-strided float16): slower NSNumber access,
            // but the index subscript honours the strides.
            var floats = [Float](repeating: 0, count: width * height)
            for y in 0 ..< height {
                for x in 0 ..< width {
                    floats[y * width + x] = multiArray[[0, y, x, 0] as [NSNumber]].floatValue
                }
            }
            return floats.withUnsafeBufferPointer {
                convert($0.baseAddress!, rowStride: width, columnStride: 1, width: width, height: height)
            }
        }
    }

    /// `UInt8(round(clip(v * 255, 0, 255)))` for a strided `width`×`height` block, one row at a time.
    private static func convert(_ base: UnsafePointer<Float>,
                                rowStride: Int,
                                columnStride: Int,
                                width: Int,
                                height: Int) -> [UInt8] {
        var scale: Float = 255
        var low: Float = 0
        var high: Float = 255
        var row = [Float](repeating: 0, count: width)

        return [UInt8](unsafeUninitializedCapacity: width * height) { pixels, initializedCount in
            row.withUnsafeMutableBufferPointer { row in
                let scratch = row.baseAddress!
                for y in 0 ..< height {
                    vDSP_vsmul(base + y * rowStride, vDSP_Stride(columnStride), &scale,
                               scratch, 1, vDSP_Length(width))
                    vDSP_vclip(scratch, 1, &low, &high, scratch, 1, vDSP_Length(width))
                    vDSP_vfixru8(scratch, 1, pixels.baseAddress! + y * width, 1, vDSP_Length(width))
                }
            }
            initializedCount = width * height
        }
    }
}


internal enum BlurMapGeometry {
    /// The size of an image's content inside a `canvasWidth`×`canvasHeight` letterbox: aspect-fit,
    /// rounded to whole pixels, and never empty.
    ///
    /// The letterbox (``CGImage/makeAspectFitPadded(width:height:orientation:)``) places the content
    /// with this size, and the blur map is cropped back out of the model output with it, so the two
    /// always agree on which pixels are image content — even for extreme aspect ratios, where the
    /// short side is a single pixel.
    static func contentSize(sourceWidth: Int, sourceHeight: Int,
                            canvasWidth: Int, canvasHeight: Int) -> (width: Int, height: Int) {
        guard sourceWidth > 0, sourceHeight > 0 else { return (canvasWidth, canvasHeight) }

        let scale = min(Double(canvasWidth) / Double(sourceWidth), Double(canvasHeight) / Double(sourceHeight))
        let width = max(Int((Double(sourceWidth) * scale).rounded()), 1)
        let height = max(Int((Double(sourceHeight) * scale).rounded()), 1)
        return (min(width, canvasWidth), min(height, canvasHeight))
    }
}


internal enum BlurMapRenderer {
    /// Builds a grayscale CGImage from width×height UInt8 pixels in row-major order.
    static func makeBlurMap(grayscaledPixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, grayscaledPixels.count == width * height else { return nil }

        // One copy into an immutable CFData that the image owns; no bitmap context round trip.
        guard let provider = CGDataProvider(data: Data(grayscaledPixels) as CFData) else { return nil }
        return CGImage(width: width,
                       height: height,
                       bitsPerComponent: 8,
                       bitsPerPixel: 8,
                       bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}
