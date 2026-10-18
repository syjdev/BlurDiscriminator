//
//  PixelBlurDetectorKitTests.swift
//  PixelBlurDetectorKitTests
//
//  Created by syjdev on 2021/11/07.
//

import XCTest
import CoreGraphics
import PixelBlurDetectorKit


class PixelBlurDetectorKitTests: XCTestCase {
    // CC0 sample images (Wikimedia Commons, public domain) bundled as test fixtures.
    private let imageNames = ["cc0_cherry_blossom.jpg",
                              "cc0_ant_sunflower.jpg",
                              "cc0_misty_river.jpg"]

    // SwiftPM copies test resources into a separate resource bundle.
    private let bundle = Bundle.module

    // The Core ML model ships in the package's resource bundle and is loaded
    // lazily on the first predict, so creating the detector is cheap.
    private let blurDetector = PixelBlurDetector()


    // End-to-end smoke test: the bundled model runs on real images and produces a
    // well-formed blur map. The exact blur ratio is model-specific, so we assert the
    // output is valid rather than pinning a magic number.
    func test_predict_with_images() async throws {
        for name in imageNames {
            let image = try XCTUnwrap(UIImage(named: name, in: bundle, compatibleWith: nil)?.cgImage,
                                      "failed to find image `\(name)`")

            let observation = try await blurDetector.predict(input: image)

            XCTAssertGreaterThan(observation.grayscaledPixels.count, 0, "\(name): empty blur map")
            XCTAssertEqual(observation.blurMap.width * observation.blurMap.height,
                           observation.grayscaledPixels.count,
                           "\(name): blur map size and pixel count disagree")

            let ratio = observation.blurRatio()
            XCTAssert((0...1).contains(ratio), "\(name): blur ratio \(ratio) out of range")

            let timings = observation.timings
            XCTAssertGreaterThan(timings.inference, .zero, "\(name): inference time not measured")
            XCTAssertEqual(timings.total, timings.preprocessing + timings.inference + timings.postprocessing)
        }
    }

}
