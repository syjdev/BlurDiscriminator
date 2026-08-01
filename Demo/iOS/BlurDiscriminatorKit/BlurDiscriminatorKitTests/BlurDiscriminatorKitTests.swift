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
    private var blurDiscriminator: BlurDiscriminator?
    
    
    override func setUpWithError() throws {
        guard let modelPath = bundle.path(forResource: "blur_segmentation_qat", ofType: "tflite")
        else {
            fatalError("failed to find `blur_segmentation_quantized.tflite`")
        }
        
        
        
        blurDiscriminator = BlurDiscriminator(modelPath: modelPath, numberOfThread: 2)
    }

    
    override func tearDownWithError() throws {
        blurDiscriminator = nil
    }

    
    func test_predict_with_images() throws {
        for testData in testDatas {
            guard let image = UIImage(named: testData.name, in: bundle, compatibleWith: nil)?.cgImage else {
                fatalError("failed to find a image, `\(testData.name)`")
            }
            
            guard let observation = blurDiscriminator?.predict(input: image) else {
                fatalError("failed to predict, image name - `\(testData.name)`")
            }
            
            let blurRatio = observation.blurRatio(threshold: 127)
            let assertMessage = """
            Result blurRatio of predict should be similar with expectedBlurRatio.
            Check this, \(testData.name). result: \(blurRatio), expected: \(testData.expectedBlurRatio)
            """

            XCTAssert(abs(blurRatio - testData.expectedBlurRatio) < 1, assertMessage)
        }
    }

}
