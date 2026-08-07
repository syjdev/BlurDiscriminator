//
//  BlurDiscriminatorKitTests.swift
//  BlurDiscriminatorKitTests
//
//  Created by syjdev on 2021/11/07.
//

import XCTest
import CoreGraphics
import BlurDiscriminatorKit


class BlurDiscriminatorKitTests: XCTestCase {
    struct TestData {
        let name: String
        let expectedBlurRatio: Float
    }

    private let testDatas = [TestData(name: "dut_test_0041.jpg", expectedBlurRatio: 0.65),
                              TestData(name: "dut_test_0044.jpg", expectedBlurRatio: 0.76),
                              TestData(name: "dut_test_0189.jpg", expectedBlurRatio: 0.94)]

    private lazy var bundle: Bundle = {
        return Bundle(for: type(of: self))
    }()

    // The Core ML model ships inside BlurDiscriminatorKit.framework and is loaded
    // lazily on the first predict, so creating the discriminator is cheap.
    private let blurDiscriminator = BlurDiscriminator()


    func test_predict_with_images() async throws {
        for testData in testDatas {
            let image = try XCTUnwrap(UIImage(named: testData.name, in: bundle, compatibleWith: nil)?.cgImage,
                                      "failed to find a image, `\(testData.name)`")

            let observation = try await blurDiscriminator.predict(input: image)

            let blurRatio = observation.blurRatio()
            let assertMessage = """
            Result blurRatio of predict should be similar with expectedBlurRatio.
            Check this, \(testData.name). result: \(blurRatio), expected: \(testData.expectedBlurRatio)
            """

            XCTAssert(abs(blurRatio - testData.expectedBlurRatio) < 1, assertMessage)
        }
    }

}
