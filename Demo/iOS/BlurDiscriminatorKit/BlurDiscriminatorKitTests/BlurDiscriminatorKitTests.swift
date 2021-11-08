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
    
    private let testDatas = [TestData(name: "image_f264_horizontal_fliped.jpg", expectedBlurRatio: 0.75),
                              TestData(name: "image_f67_origin.jpg", expectedBlurRatio: 0.75),
                              TestData(name: "image_f477_origin.jpg", expectedBlurRatio: 0.73)]
    
    private lazy var bundle: Bundle = {
        return Bundle(for: type(of: self))
    }()
    private var blurDiscriminator: BlurDiscriminator?
    
    
    override func setUpWithError() throws {
        guard let modelPath = bundle.path(forResource: "blur_segmentation_quantized", ofType: "tflite")
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
            
            let assertMessage = """
            Result blurRatio of predict should be similar with expectedBlurRatio.
            Check this, \(testData.name). result: \(observation.blurRatio), expected: \(testData.expectedBlurRatio)
            """
            
            XCTAssert(abs(observation.blurRatio - testData.expectedBlurRatio) < 1, assertMessage)
        }
    }

}
