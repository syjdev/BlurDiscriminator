// SPDX-License-Identifier: Apache-2.0
//
//  CGImage+resize.swift
//  PixelBlurDetectorKit
//
//  Created by syjdev on 2021/10/07.
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO


extension CGImage {
    /// Returns a `width`×`height` 32BGRA pixel buffer with `self` aspect-fit into the top-left corner
    /// and the remaining area padded with black, ready to be fed to the Core ML model.
    ///
    /// This reproduces the letterbox preprocessing the model was trained with: the aspect ratio is
    /// preserved (no stretching), and the padding is placed at the bottom/right so the content is
    /// top-left aligned. ``BlurMapGeometry`` later crops the model output back to this same region.
    ///
    /// The downscale uses a hand-written **half-pixel bilinear** resampler rather than
    /// `CGContext`'s built-in interpolation. Blur detection is extremely sensitive to the
    /// resampling filter, and Core Graphics' resamplers (even `.none`/`.low`) do not match the
    /// model's training resize (`tf.image.resize` / `cv2.INTER_LINEAR`). This bilinear matches both
    /// the training pipeline and the Android port (`ImagePreprocessor.letterboxRgb`) bit for bit —
    /// pinned on both sides by the same digests (`ImageProcessingTests.parityDigests`).
    ///
    /// `orientation` is applied while sampling: the resampler reads the raw pixels through a rotated
    /// / mirrored index mapping, so an EXIF-rotated photo never has to be redrawn upright first.
    ///
    /// The hot loop uses unsafe buffer pointers, `Float` math, and precomputed sampling tables so it
    /// stays cheap despite running per output pixel.
    func makeAspectFitPadded(width: Int,
                             height: Int,
                             orientation: CGImagePropertyOrientation = .up) -> CVPixelBuffer? {
        guard self.width > 0, self.height > 0, width > 0, height > 0,
              let pixelBuffer = Self.makePixelBuffer(width: width, height: height)
        else {
            return nil
        }

        let resampled = withRGBPixels { source -> Bool in
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
            guard let destination = CVPixelBufferGetBaseAddress(pixelBuffer) else { return false }

            resample(source,
                     orientation: orientation,
                     into: destination.assumingMemoryBound(to: UInt8.self),
                     width: width,
                     height: height,
                     bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer))
            return true
        }
        return resampled == true ? pixelBuffer : nil
    }

    /// The image's size after `orientation` is applied — the size the user sees.
    func orientedSize(_ orientation: CGImagePropertyOrientation) -> (width: Int, height: Int) {
        return orientation.swapsAxes ? (height, width) : (width, height)
    }

    // MARK: - resampling

    private func resample(_ source: RGBPixels,
                          orientation: CGImagePropertyOrientation,
                          into dst: UnsafeMutablePointer<UInt8>,
                          width: Int,
                          height: Int,
                          bytesPerRow: Int) {
        let (sourceWidth, sourceHeight) = orientedSize(orientation)
        let (contentWidth, contentHeight) = BlurMapGeometry.contentSize(sourceWidth: sourceWidth,
                                                                        sourceHeight: sourceHeight,
                                                                        canvasWidth: width,
                                                                        canvasHeight: height)
        let xRatio = Double(sourceWidth) / Double(contentWidth)
        let yRatio = Double(sourceHeight) / Double(contentHeight)
        let offsets = source.offsets(for: orientation, rawWidth: self.width, rawHeight: self.height)

        // Precompute the horizontal sample offsets/weights once; they repeat for every row.
        var leftOffset = [Int](repeating: 0, count: contentWidth)
        var rightOffset = [Int](repeating: 0, count: contentWidth)
        var xWeight = [Float](repeating: 0, count: contentWidth)
        for dx in 0 ..< contentWidth {
            let fx = Float(max((Double(dx) + 0.5) * xRatio - 0.5, 0))
            let x0 = min(Int(fx), sourceWidth - 1)
            leftOffset[dx] = offsets.column(x0)
            rightOffset[dx] = offsets.column(min(x0 + 1, sourceWidth - 1))
            xWeight[dx] = fx - Float(x0)
        }

        // Padding is black with alpha 0, matching the letterbox the model was trained with.
        memset(dst, 0, bytesPerRow * height)

        let src = source.base
        let (red, green, blue) = (source.red, source.green, source.blue)
        for dy in 0 ..< contentHeight {
            let fy = Float(max((Double(dy) + 0.5) * yRatio - 0.5, 0))
            let y0 = min(Int(fy), sourceHeight - 1)
            let y1 = min(y0 + 1, sourceHeight - 1)
            let wy = fy - Float(y0)
            let inverseWY = 1 - wy
            let row0 = offsets.row(y0)
            let row1 = offsets.row(y1)
            var destination = dy * bytesPerRow
            for dx in 0 ..< contentWidth {
                let wx = xWeight[dx]
                let inverseWX = 1 - wx
                let left = leftOffset[dx]
                let right = rightOffset[dx]
                let p00 = src + row0 + left, p01 = src + row0 + right
                let p10 = src + row1 + left, p11 = src + row1 + right

                @inline(__always)
                func sample(_ channel: Int) -> UInt8 {
                    let top = Float(p00[channel]) * inverseWX + Float(p01[channel]) * wx
                    let bottom = Float(p10[channel]) * inverseWX + Float(p11[channel]) * wx
                    return UInt8((top * inverseWY + bottom * wy).rounded())
                }

                // 32BGRA
                dst[destination] = sample(blue)
                dst[destination + 1] = sample(green)
                dst[destination + 2] = sample(red)
                dst[destination + 3] = 255
                destination += 4
            }
        }
    }

    private static func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        // IOSurface-backed so Core ML can hand it to the GPU / Neural Engine without a copy.
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         attributes,
                                         &pixelBuffer)
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }

    // MARK: - pixel access

    /// Calls `body` with the image's 8-bit RGB pixels, top row first.
    ///
    /// When the image is already stored as 8-bit sRGB, its decoded bytes are read in place — no
    /// redraw, no color conversion. Any other format (wide gamut, 16-bit, non-premultiplied alpha,
    /// …) is first drawn into an RGBA8 device-RGB buffer, which is what Core Graphics would convert
    /// it to anyway.
    private func withRGBPixels<Result>(_ body: (RGBPixels) -> Result) -> Result? {
        if let layout = directPixelLayout,
           let data = dataProvider?.data,
           CFDataGetLength(data) >= bytesPerRow * (height - 1) + width * layout.bytesPerPixel,
           let base = CFDataGetBytePtr(data) {
            return withExtendedLifetime(data) {
                body(RGBPixels(base: base, bytesPerRow: bytesPerRow, layout: layout))
            }
        }

        guard let buffer = drawRGBA8() else { return nil }
        return buffer.withUnsafeBufferPointer { pointer in
            body(RGBPixels(base: pointer.baseAddress!, bytesPerRow: width * 4, layout: .rgba))
        }
    }

    /// The channel layout of the image's own bytes, or `nil` when they can't be read as-is.
    ///
    /// Only sRGB / device-RGB images qualify: drawing those into the device-RGB fallback buffer is
    /// an identity copy, so reading them in place yields exactly the same pixels. Premultiplied
    /// alpha qualifies for the same reason (it is what the fallback buffer stores).
    private var directPixelLayout: PixelLayout? {
        guard bitsPerComponent == 8,
              !bitmapInfo.contains(.floatComponents),
              let colorSpace,
              colorSpace.model == .rgb,
              let name = colorSpace.name as String?,
              name == CGColorSpace.sRGB as String || name == CGColorSpaceCreateDeviceRGB().name as String?
        else {
            return nil
        }

        let alphaFirst: Bool
        switch alphaInfo {
        case .none:
            // 24bpp RGB, the only 8-bit layout without an alpha or padding byte.
            guard bitsPerPixel == 24, byteOrderInfo == .orderDefault else { return nil }
            return PixelLayout(bytesPerPixel: 3, red: 0, green: 1, blue: 2)
        case .noneSkipLast, .premultipliedLast:
            alphaFirst = false
        case .noneSkipFirst, .premultipliedFirst:
            alphaFirst = true
        default:
            // Non-premultiplied alpha or alpha-only: needs a real conversion.
            return nil
        }

        guard bitsPerPixel == 32 else { return nil }
        switch byteOrderInfo {
        case .orderDefault, .order32Big:
            return alphaFirst ? PixelLayout(bytesPerPixel: 4, red: 1, green: 2, blue: 3)   // ARGB
                              : .rgba                                                      // RGBA
        case .order32Little:
            return alphaFirst ? PixelLayout(bytesPerPixel: 4, red: 2, green: 1, blue: 0)   // BGRA
                              : PixelLayout(bytesPerPixel: 4, red: 3, green: 2, blue: 1)   // ABGR
        default:
            return nil
        }
    }

    /// Draws the image into a tightly packed, premultiplied RGBA8 device-RGB buffer.
    private func drawRGBA8() -> [UInt8]? {
        let width = self.width
        let height = self.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? buffer : nil
    }
}


/// Byte offsets of the red, green and blue channels within one pixel.
private struct PixelLayout {
    let bytesPerPixel: Int
    let red: Int
    let green: Int
    let blue: Int

    static let rgba = PixelLayout(bytesPerPixel: 4, red: 0, green: 1, blue: 2)
}


/// A read-only view of an image's 8-bit RGB pixels, top row first.
private struct RGBPixels {
    let base: UnsafePointer<UInt8>
    let bytesPerRow: Int
    let layout: PixelLayout

    var red: Int { layout.red }
    var green: Int { layout.green }
    var blue: Int { layout.blue }

    /// Maps oriented (displayed) coordinates to byte offsets into the raw pixels.
    ///
    /// Every EXIF orientation maps displayed `(x, y)` to raw `(rx, ry)` with each raw axis driven by
    /// exactly one displayed axis, so the offset `rx * bytesPerPixel + ry * bytesPerRow` splits into
    /// an x-only `column` term plus a y-only `row` term — which is what lets the resampler keep its
    /// per-column lookup table while reading the image rotated.
    func offsets(for orientation: CGImagePropertyOrientation,
                 rawWidth: Int,
                 rawHeight: Int) -> (column: (Int) -> Int, row: (Int) -> Int) {
        let pixel = layout.bytesPerPixel
        let row = bytesPerRow
        let lastX = rawWidth - 1
        let lastY = rawHeight - 1

        switch orientation {
        case .up:            return ({ $0 * pixel },           { $0 * row })
        case .upMirrored:    return ({ (lastX - $0) * pixel }, { $0 * row })
        case .down:          return ({ (lastX - $0) * pixel }, { (lastY - $0) * row })
        case .downMirrored:  return ({ $0 * pixel },           { (lastY - $0) * row })
        case .leftMirrored:  return ({ $0 * row },             { $0 * pixel })
        case .right:         return ({ (lastY - $0) * row },   { $0 * pixel })
        case .rightMirrored: return ({ (lastY - $0) * row },   { (lastX - $0) * pixel })
        case .left:          return ({ $0 * row },             { (lastX - $0) * pixel })
        @unknown default:    return ({ $0 * pixel },           { $0 * row })
        }
    }
}


extension CGImagePropertyOrientation {
    /// Whether the displayed image is the raw image transposed (rotated by ±90°).
    var swapsAxes: Bool {
        switch self {
        case .leftMirrored, .right, .rightMirrored, .left:
            return true
        default:
            return false
        }
    }
}
