//
//  ImageProcessingTests.swift
//  PixelBlurDetectorKitTests
//
//  Pins the image pipeline's pixels: the letterbox preprocessing against a straightforward
//  reference implementation (draw the whole image, then resample), and the model-output
//  conversion against hand-computed values for strided / half-precision outputs.
//

import XCTest
import CoreGraphics
import CoreML
import CoreVideo
import CryptoKit
import ImageIO
import UIKit
@testable import PixelBlurDetectorKit


class ImageProcessingTests: XCTestCase {
    private let fixtureNames = ["cc0_cherry_blossom.jpg",
                                "cc0_ant_sunflower.jpg",
                                "cc0_misty_river.jpg"]

    private static let allOrientations: [CGImagePropertyOrientation] = [
        .up, .upMirrored, .down, .downMirrored, .leftMirrored, .right, .rightMirrored, .left,
    ]


    // MARK: - letterbox

    func test_letterbox_matches_reference_for_fixtures() throws {
        for name in fixtureNames {
            let image = try fixture(name)
            XCTAssertEqual(try letterboxed(image), try XCTUnwrap(Self.referenceLetterbox(image)), name)
        }
    }

    func test_letterbox_matches_reference_for_pixel_layouts() throws {
        let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let displayP3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let little = CGBitmapInfo.byteOrder32Little.rawValue

        let layouts: [(String, CGImage?)] = [
            ("RGBX", Self.makeImage(space: sRGB, alpha: .noneSkipLast)),
            ("XRGB", Self.makeImage(space: sRGB, alpha: .noneSkipFirst)),
            ("BGRA premultiplied", Self.makeImage(space: sRGB, alpha: .premultipliedFirst, byteOrder: little)),
            ("ABGR premultiplied", Self.makeImage(space: sRGB, alpha: .premultipliedLast, byteOrder: little)),
            ("RGB 24bpp", Self.makeImage(space: sRGB, alpha: .none, bitsPerPixel: 24)),
            ("padded rows", Self.makeImage(space: sRGB, alpha: .noneSkipLast, rowPadding: 12)),
            ("device RGB", Self.makeImage(space: CGColorSpaceCreateDeviceRGB(), alpha: .noneSkipLast)),
            // Not readable in place — exercises the redraw fallback.
            ("Display P3", Self.makeImage(space: displayP3, alpha: .noneSkipLast)),
            ("RGBA straight alpha", Self.makeImage(space: sRGB, alpha: .last)),
        ]

        for (name, image) in layouts {
            let image = try XCTUnwrap(image, name)
            XCTAssertEqual(try letterboxed(image), try XCTUnwrap(Self.referenceLetterbox(image)), name)
        }
    }

    func test_letterbox_reads_rotated_pixels_like_an_upright_redraw() throws {
        let images = [try fixture("cc0_cherry_blossom.jpg"),
                      try XCTUnwrap(Self.makeImage(space: CGColorSpace(name: CGColorSpace.sRGB)!, alpha: .noneSkipLast))]

        for image in images {
            for orientation in Self.allOrientations {
                let upright = try XCTUnwrap(Self.drawUpright(image, orientation: orientation))
                XCTAssertEqual(try letterboxed(image, orientation: orientation),
                               try XCTUnwrap(Self.referenceLetterbox(upright)),
                               "orientation \(orientation.rawValue), \(image.width)x\(image.height)")
            }
        }
    }

    func test_predict_returns_blur_map_in_displayed_orientation() async throws {
        let image = try fixture("cc0_cherry_blossom.jpg")
        let upright = try XCTUnwrap(Self.drawUpright(image, orientation: .right))
        let detector = PixelBlurDetector()

        let rotated = try await detector.predict(input: image, orientation: .right)
        let expected = try await detector.predict(input: upright)

        XCTAssertEqual(rotated.blurMap.width, expected.blurMap.width)
        XCTAssertEqual(rotated.blurMap.height, expected.blurMap.height)
        XCTAssertLessThan(rotated.blurMap.width, rotated.blurMap.height, "a .right landscape photo is portrait")
        XCTAssertEqual(rotated.grayscaledPixels, expected.grayscaledPixels)
    }


    // MARK: - cross-platform parity

    /// SHA-256 of the letterboxed RGB bytes of ``makeParityImage(width:height:)`` images.
    ///
    /// The Android port (`ImagePreprocessorTest.kt`) pins the very same digests, so a change to the
    /// resampler on either platform that would make their model inputs diverge fails a test. Update
    /// both files together, and only on purpose.
    static let parityDigests: [(width: Int, height: Int, orientation: CGImagePropertyOrientation, sha256: String)] = [
        (37, 23, .up, "97b50d8254ba663c7c78c5e2f166f3c8f770428eb44b6135c44fd03c768d8691"),
        (13, 17, .up, "c3164510f13b3fc69f00c2b831e8d829c7b83bf87c476adc5f35c3e8ef7fab52"),
        (300, 7, .up, "45a351783624b81ea750604575517fda8fdb9b48bd5f2f7a9a2bba5ff8a2e8de"),
        (640, 480, .up, "9370a60ba05455b35c8fcb77ce083224e40207a3ba73956a9962e99ed55700de"),
        (480, 641, .up, "83eaf9f8d56f4ab82bebd59f332327b50b9127b69749eb798ea063d91f8e47de"),
        (37, 23, .upMirrored, "4d9520a71244439b17175e6db7e023255271ee951b828cc0c04df4cd1c621d3e"),
        (37, 23, .down, "2620723f71cdeeddc1e75dbbcef64c6eea3a91c936741b0f1954f58b3b953a33"),
        (37, 23, .downMirrored, "5174553b7ccac96a90f3a1ac59620c77624a99320ab0ce97aacbb1fbb69392b6"),
        (37, 23, .leftMirrored, "7f73281571f0033766ec6d2f28a84fff6054d55cb53afb81548c8572b2a56778"),
        (37, 23, .right, "3d17911245a5632cd4f5f8fed259e344b8ac078d6d0becccf0a48660f5bdd067"),
        (37, 23, .rightMirrored, "2ad50885144c0f555a65c8962eac67538e335b926b410e9517fe92678f235ed2"),
        (37, 23, .left, "7a92bbcbfb49a18a74b089bae0c579d381e6cc3d3067f26dbb0b73e9e73e1279"),
        (640, 480, .right, "c32804e265c0ac500035fa672eeafd9020a3a8eb6fc9a4cfc21df289cea72eaa"),
        (480, 641, .left, "60cad1358cabf410b7f0303ed7e321d5ddccc8735b163a75b700b821e367942b"),
    ]

    func test_letterbox_matches_the_android_port() throws {
        for (width, height, orientation, sha256) in Self.parityDigests {
            let image = try XCTUnwrap(Self.makeParityImage(width: width, height: height))
            let rgba = try letterboxed(image, orientation: orientation)
            var rgb = [UInt8]()
            rgb.reserveCapacity(224 * 224 * 3)
            for pixel in stride(from: 0, to: rgba.count, by: 4) {
                rgb.append(contentsOf: rgba[pixel ..< pixel + 3])
            }
            let digest = SHA256.hash(data: rgb).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, sha256, "\(width)x\(height), orientation \(orientation.rawValue)")
        }
    }


    // MARK: - letterbox geometry

    func test_content_size_rounds_and_never_collapses() {
        func size(_ w: Int, _ h: Int) -> [Int] {
            let s = BlurMapGeometry.contentSize(sourceWidth: w, sourceHeight: h, canvasWidth: 224, canvasHeight: 224)
            return [s.width, s.height]
        }
        XCTAssertEqual(size(1024, 682), [224, 149])   // 149.19 → 149
        XCTAssertEqual(size(1000, 668), [224, 150])   // 149.63 → 150: the row the letterbox fills is kept
        XCTAssertEqual(size(682, 1024), [149, 224])
        XCTAssertEqual(size(500, 500), [224, 224])
        XCTAssertEqual(size(2240, 9), [224, 1])       // 0.9 → 1, not 0
        XCTAssertEqual(size(5000, 3), [224, 1])       // 0.13 → clamped to 1
        XCTAssertEqual(size(3, 5000), [1, 224])
    }

    func test_predict_handles_extreme_aspect_ratios() async throws {
        let detector = PixelBlurDetector()
        for (width, height) in [(2240, 9), (5000, 3), (3, 5000), (1000, 668)] {
            let image = try XCTUnwrap(Self.makeSolidImage(width: width, height: height))
            let expected = BlurMapGeometry.contentSize(sourceWidth: width, sourceHeight: height,
                                                       canvasWidth: 224, canvasHeight: 224)

            let observation = try await detector.predict(input: image)

            XCTAssertEqual(observation.blurMap.width, expected.width, "\(width)x\(height)")
            XCTAssertEqual(observation.blurMap.height, expected.height, "\(width)x\(height)")
        }
    }


    // MARK: - model output

    func test_grayscale_conversion_honors_row_padding() throws {
        // 1x4x3x1 map whose rows are padded to 8 elements and columns spaced by 2 — the padding
        // holds values that would show up as white if it were ever read.
        let values: [[Float]] = [[0.0, 0.25, 1.0],
                                 [-0.5, 0.11, 0.91],
                                 [1.7, 0.333, 0.66],
                                 [0.2, 0.8, 0.05]]
        let multiArray = try Self.makeMultiArray(values, rowStride: 8, columnStride: 2, padding: 2.0)

        let pixels = try PixelConverter.grayscalePixels(from: multiArray, width: 2, height: 3)

        XCTAssertEqual(pixels, Self.expectedPixels(values, width: 2, height: 3))
    }

    func test_grayscale_conversion_of_float16_output() throws {
        #if arch(arm64)
        let values: [[Float]] = [[0.0, 0.25, 1.0],
                                 [-0.5, 0.125, 0.875],
                                 [1.5, 0.375, 0.625]]
        for columnStride in [1, 2] {  // 2 takes the strided NSNumber fallback
            let multiArray = try Self.makeFloat16MultiArray(values, rowStride: 8, columnStride: columnStride)
            let pixels = try PixelConverter.grayscalePixels(from: multiArray, width: 3, height: 2)
            XCTAssertEqual(pixels, Self.expectedPixels(values, width: 3, height: 2), "column stride \(columnStride)")
        }
        #else
        throw XCTSkip("Float16 is unavailable on this architecture")
        #endif
    }

    func test_grayscale_conversion_of_double_output() throws {
        let values: [[Float]] = [[0.0, 0.25], [0.75, 1.25]]
        let multiArray = try MLMultiArray(shape: [1, 2, 2, 1], dataType: .double)
        for y in 0 ..< 2 {
            for x in 0 ..< 2 {
                multiArray[[0, y, x, 0] as [NSNumber]] = NSNumber(value: values[y][x])
            }
        }

        let pixels = try PixelConverter.grayscalePixels(from: multiArray, width: 2, height: 2)

        XCTAssertEqual(pixels, Self.expectedPixels(values, width: 2, height: 2))
    }

    func test_grayscale_conversion_rejects_crop_larger_than_output() throws {
        let multiArray = try Self.makeMultiArray([[0.5, 0.5]], rowStride: 2, columnStride: 1, padding: 0)
        XCTAssertThrowsError(try PixelConverter.grayscalePixels(from: multiArray, width: 3, height: 1))
    }

    func test_blur_map_image_holds_the_pixels() throws {
        let pixels: [UInt8] = [0, 64, 128, 255, 10, 20]
        let image = try XCTUnwrap(BlurMapRenderer.makeBlurMap(grayscaledPixels: pixels, width: 3, height: 2))

        XCTAssertEqual(image.width, 3)
        XCTAssertEqual(image.height, 2)
        XCTAssertEqual([UInt8](try XCTUnwrap(image.dataProvider?.data) as Data), pixels)
    }


    // MARK: - helpers

    private func fixture(_ name: String) throws -> CGImage {
        // SwiftPM copies test resources into a separate resource bundle.
        return try XCTUnwrap(UIImage(named: name, in: .module, compatibleWith: nil)?.cgImage, "missing fixture \(name)")
    }

    /// The letterboxed 224x224 input as tightly packed RGBA, read back from the BGRA pixel buffer.
    private func letterboxed(_ image: CGImage,
                             orientation: CGImagePropertyOrientation = .up) throws -> [UInt8] {
        let buffer = try XCTUnwrap(image.makeAspectFitPadded(width: 224, height: 224, orientation: orientation))
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(buffer), kCVPixelFormatType_32BGRA)

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer)).assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        var rgba = [UInt8](repeating: 0, count: 224 * 224 * 4)
        for y in 0 ..< 224 {
            for x in 0 ..< 224 {
                let source = base + y * bytesPerRow + x * 4
                let destination = (y * 224 + x) * 4
                rgba[destination] = source[2]
                rgba[destination + 1] = source[1]
                rgba[destination + 2] = source[0]
                rgba[destination + 3] = source[3]
            }
        }
        return rgba
    }

    /// The letterbox exactly as it was before pixels were read in place: draw the whole image into
    /// an RGBA8 device-RGB context, then half-pixel bilinear into the top-left of a black canvas.
    private static func referenceLetterbox(_ image: CGImage, width: Int = 224, height: Int = 224) -> [UInt8]? {
        let sourceWidth = image.width
        let sourceHeight = image.height
        var source = [UInt8](repeating: 0, count: sourceWidth * sourceHeight * 4)
        let drawn = source.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress,
                                          width: sourceWidth,
                                          height: sourceHeight,
                                          bitsPerComponent: 8,
                                          bytesPerRow: sourceWidth * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))
            return true
        }
        guard drawn else { return nil }

        let scale = min(Double(width) / Double(sourceWidth), Double(height) / Double(sourceHeight))
        let contentWidth = max(Int((Double(sourceWidth) * scale).rounded()), 1)
        let contentHeight = max(Int((Double(sourceHeight) * scale).rounded()), 1)
        let xRatio = Double(sourceWidth) / Double(contentWidth)
        let yRatio = Double(sourceHeight) / Double(contentHeight)

        var output = [UInt8](repeating: 0, count: width * height * 4)
        for dy in 0 ..< contentHeight {
            let fy = Float(max((Double(dy) + 0.5) * yRatio - 0.5, 0))
            let y0 = min(Int(fy), sourceHeight - 1)
            let y1 = min(y0 + 1, sourceHeight - 1)
            let wy = fy - Float(y0)
            for dx in 0 ..< contentWidth {
                let fx = Float(max((Double(dx) + 0.5) * xRatio - 0.5, 0))
                let x0 = min(Int(fx), sourceWidth - 1)
                let x1 = min(x0 + 1, sourceWidth - 1)
                let wx = fx - Float(x0)
                for channel in 0 ..< 3 {
                    func at(_ x: Int, _ y: Int) -> Float { Float(source[(y * sourceWidth + x) * 4 + channel]) }
                    let top = at(x0, y0) * (1 - wx) + at(x1, y0) * wx
                    let bottom = at(x0, y1) * (1 - wx) + at(x1, y1) * wx
                    output[(dy * width + dx) * 4 + channel] = UInt8((top * (1 - wy) + bottom * wy).rounded())
                }
                output[(dy * width + dx) * 4 + 3] = 255
            }
        }
        return output
    }

    /// What the demo used to do for EXIF-rotated photos: let UIKit redraw the image upright.
    private static func drawUpright(_ image: CGImage, orientation: CGImagePropertyOrientation) -> CGImage? {
        let oriented = UIImage(cgImage: image, scale: 1, orientation: UIImage.Orientation(orientation))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: oriented.size, format: format).image { _ in
            oriented.draw(at: .zero)
        }.cgImage
    }

    /// An opaque, noisy sRGB image whose bytes come from a 32-bit LCG — reproduced exactly by
    /// `ImagePreprocessorTest.parityImage` on Android.
    private static func makeParityImage(width: Int, height: Int) -> CGImage? {
        var seed: UInt32 = 12345
        var bytes = [UInt8]()
        bytes.reserveCapacity(width * height * 4)
        for _ in 0 ..< width * height {
            for _ in 0 ..< 3 {
                seed = seed &* 1_103_515_245 &+ 12345
                bytes.append(UInt8(truncatingIfNeeded: seed >> 16))
            }
            bytes.append(255)
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width,
                       height: height,
                       bitsPerComponent: 8,
                       bitsPerPixel: 32,
                       bytesPerRow: width * 4,
                       space: sRGB,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent)
    }

    private static func makeSolidImage(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            return nil
        }
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// A deterministic, noisy 37x23 image in the requested pixel layout.
    private static func makeImage(space: CGColorSpace,
                                  alpha: CGImageAlphaInfo,
                                  byteOrder: UInt32 = 0,
                                  bitsPerPixel: Int = 32,
                                  rowPadding: Int = 0) -> CGImage? {
        let width = 37
        let height = 23
        let bytesPerPixel = bitsPerPixel / 8
        let bytesPerRow = width * bytesPerPixel + rowPadding
        let premultiplied = alpha == .premultipliedFirst || alpha == .premultipliedLast
        let hasAlpha = premultiplied || alpha == .first || alpha == .last

        var seed: UInt32 = 12345
        func next() -> UInt8 {
            seed = seed &* 1_103_515_245 &+ 12345
            return UInt8(truncatingIfNeeded: seed >> 16)
        }

        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let a: UInt8 = hasAlpha ? max(next(), 1) : 255
                var rgb = [next(), next(), next()]
                if premultiplied {
                    rgb = rgb.map { UInt8(Int($0) * Int(a) / 255) }
                }
                let alphaFirst = alpha == .premultipliedFirst || alpha == .first || alpha == .noneSkipFirst
                var pixel = bytesPerPixel == 3 ? rgb : (alphaFirst ? [a] + rgb : rgb + [a])
                if byteOrder == CGBitmapInfo.byteOrder32Little.rawValue {
                    pixel.reverse()
                }
                let offset = y * bytesPerRow + x * bytesPerPixel
                bytes.replaceSubrange(offset ..< offset + bytesPerPixel, with: pixel)
            }
        }

        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width,
                       height: height,
                       bitsPerComponent: 8,
                       bitsPerPixel: bitsPerPixel,
                       bytesPerRow: bytesPerRow,
                       space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: alpha.rawValue | byteOrder),
                       provider: provider,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent)
    }

    private static func makeMultiArray(_ values: [[Float]],
                                       rowStride: Int,
                                       columnStride: Int,
                                       padding: Float) throws -> MLMultiArray {
        let height = values.count
        let width = values[0].count
        let storage = UnsafeMutablePointer<Float>.allocate(capacity: height * rowStride)
        storage.initialize(repeating: padding, count: height * rowStride)
        for y in 0 ..< height {
            for x in 0 ..< width {
                storage[y * rowStride + x * columnStride] = values[y][x]
            }
        }
        return try MLMultiArray(dataPointer: storage,
                                shape: [1, NSNumber(value: height), NSNumber(value: width), 1],
                                dataType: .float32,
                                strides: [NSNumber(value: height * rowStride), NSNumber(value: rowStride),
                                          NSNumber(value: columnStride), 1],
                                deallocator: { $0.deallocate() })
    }

    #if arch(arm64)
    private static func makeFloat16MultiArray(_ values: [[Float]],
                                              rowStride: Int,
                                              columnStride: Int) throws -> MLMultiArray {
        let height = values.count
        let width = values[0].count
        let storage = UnsafeMutablePointer<Float16>.allocate(capacity: height * rowStride)
        storage.initialize(repeating: 2.0, count: height * rowStride)
        for y in 0 ..< height {
            for x in 0 ..< width {
                storage[y * rowStride + x * columnStride] = Float16(values[y][x])
            }
        }
        return try MLMultiArray(dataPointer: storage,
                                shape: [1, NSNumber(value: height), NSNumber(value: width), 1],
                                dataType: .float16,
                                strides: [NSNumber(value: height * rowStride), NSNumber(value: rowStride),
                                          NSNumber(value: columnStride), 1],
                                deallocator: { $0.deallocate() })
    }
    #endif

    /// `round(clip(v * 255, 0, 255))` for the top-left `width`x`height` block.
    private static func expectedPixels(_ values: [[Float]], width: Int, height: Int) -> [UInt8] {
        return (0 ..< height).flatMap { y in
            (0 ..< width).map { x in UInt8(min(max(values[y][x] * 255, 0), 255).rounded()) }
        }
    }
}


private extension UIImage.Orientation {
    init(_ orientation: CGImagePropertyOrientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

