// SPDX-License-Identifier: Apache-2.0
//
//  CoreMLBlurPredictor.swift
//  PixelBlurDetectorKit
//
//  Runs BlurSegmentation.mlpackage.
//  The Core ML model takes a 224x224 RGB image (pixel values 0-255, the
//  1/255 normalization is baked into the model) and outputs a 1x224x224x1
//  float map where bright = blurred.
//

import CoreGraphics
import CoreML
import Dispatch
import ImageIO


/// Core ML inference engine behind ``PixelBlurDetector``. Kept internal so the module's public
/// surface stays limited to ``PixelBlurDetector`` and ``BlurObservation``.
///
/// `@unchecked Sendable`: all stored properties are immutable, and every prediction runs on one
/// serial queue, so the model is never used from two threads at once. (`MLModel` itself just isn't
/// annotated.)
internal final class CoreMLBlurPredictor: BlurPredicting, @unchecked Sendable {
    private struct MalformedModelError: Error { let reason: String }

    private let model: MLModel
    private let inputName: String
    private let outputName: String
    private let inputWidth: Int
    private let inputHeight: Int

    /// Preprocessing and the Core ML call are synchronous work (tens of milliseconds). Running them
    /// here instead of inline keeps them off Swift concurrency's small cooperative thread pool,
    /// which must never be blocked; being serial, it also runs predictions one at a time.
    private let queue = DispatchQueue(label: "dev.syjdev.PixelBlurDetectorKit.inference", qos: .userInitiated)

    /// Loads the compiled model that ships in this package's resource bundle.
    ///
    /// `BlurSegmentation` is the class Xcode generates from `BlurSegmentation.mlpackage`;
    /// its loader resolves `BlurSegmentation.mlmodelc` inside this package's resource bundle,
    /// so there is no bundle/URL lookup to get wrong here.
    ///
    /// - Throws: ``PixelBlurDetectorError/modelLoadFailed(underlying:)`` if loading fails.
    init() async throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all  // CPU / GPU / Neural Engine

        do {
            let segmentation = try await BlurSegmentation.load(configuration: configuration)
            let mlModel = segmentation.model
            let description = mlModel.modelDescription

            // Read the input/output names and the required input size from the model instead of
            // hardcoding them, so a reconverted model keeps working.
            guard let imageInput = description.inputDescriptionsByName.values.first(where: { $0.type == .image }),
                  let constraint = imageInput.imageConstraint else {
                throw MalformedModelError(reason: "model has no image input constraint")
            }
            guard let mapOutput = description.outputDescriptionsByName.values.first(where: { $0.type == .multiArray }) else {
                throw MalformedModelError(reason: "model has no multi-array output")
            }
            self.model = mlModel
            self.inputName = imageInput.name
            self.outputName = mapOutput.name
            self.inputWidth = constraint.pixelsWide
            self.inputHeight = constraint.pixelsHigh
        } catch {
            throw PixelBlurDetectorError.modelLoadFailed(underlying: error)
        }
    }

    func predict(input: CGImage, orientation: CGImagePropertyOrientation) async throws -> BlurObservation {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result {
                    try self.predictSynchronously(input: input, orientation: orientation)
                })
            }
        }
    }

    private func predictSynchronously(input: CGImage,
                                      orientation: CGImagePropertyOrientation) throws -> BlurObservation {
        let clock = ContinuousClock()
        let start = clock.now

        // Letterbox straight into a pixel buffer of the model's input size, so the model sees the
        // same undistorted, black-padded image it was trained on and Core ML has nothing left to
        // resize or convert.
        guard let paddedInput = input.makeAspectFitPadded(width: inputWidth,
                                                          height: inputHeight,
                                                          orientation: orientation) else {
            throw PixelBlurDetectorError.imagePreprocessingFailed
        }
        let preprocessed = clock.now

        let output: MLFeatureProvider
        do {
            let features = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: paddedInput)])
            output = try model.prediction(from: features)
        } catch {
            throw PixelBlurDetectorError.inferenceFailed(underlying: error)
        }
        let inferred = clock.now

        guard let multiArray = output.featureValue(for: outputName)?.multiArrayValue else {
            throw PixelBlurDetectorError.unexpectedOutput
        }

        let displayed = input.orientedSize(orientation)
        let (blurMap, pixels) = try makeBlurMap(from: multiArray,
                                                originalWidth: displayed.width,
                                                originalHeight: displayed.height)
        let timings = BlurObservation.Timings(preprocessing: preprocessed - start,
                                              inference: inferred - preprocessed,
                                              postprocessing: clock.now - inferred)
        return BlurObservation(blurMap: blurMap, grayscaledPixels: pixels, timings: timings)
    }

    private func makeBlurMap(from multiArray: MLMultiArray,
                             originalWidth: Int,
                             originalHeight: Int) throws -> (CGImage, [UInt8]) {
        // The model outputs a 1xHxWx1 (NHWC) sigmoid map. Take the blur-map size from
        // the actual output tensor instead of hardcoding the model's current 224x224.
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count == 4, shape[0] == 1, shape[3] == 1 else {
            throw PixelBlurDetectorError.unexpectedOutput
        }
        let outputHeight = shape[1]
        let outputWidth = shape[2]

        // Only the un-padded region matches the original image's aspect ratio; convert just that.
        let cropped = BlurMapGeometry.contentSize(sourceWidth: originalWidth,
                                                  sourceHeight: originalHeight,
                                                  canvasWidth: outputWidth,
                                                  canvasHeight: outputHeight)
        let pixels = try PixelConverter.grayscalePixels(from: multiArray,
                                                        width: cropped.width,
                                                        height: cropped.height)

        guard let blurMap = BlurMapRenderer.makeBlurMap(grayscaledPixels: pixels,
                                                        width: cropped.width,
                                                        height: cropped.height) else {
            throw PixelBlurDetectorError.unexpectedOutput
        }
        return (blurMap, pixels)
    }
}
