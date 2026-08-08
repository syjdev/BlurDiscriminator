// SPDX-License-Identifier: Apache-2.0
//
//  CoreMLBlurPredictor.swift
//  BlurDiscriminatorKit
//
//  Runs BlurSegmentation.mlpackage (converted by snorlax/convert_model.py).
//  The Core ML model takes a 224x224 RGB image (pixel values 0-255, the
//  1/255 normalization is baked into the model) and outputs a 1x224x224x1
//  float map where bright = blurred.
//

import Accelerate
import CoreGraphics
import CoreML
import Vision


/// Core ML inference engine behind ``BlurDiscriminator``. Kept internal so the framework's public
/// surface stays limited to ``BlurDiscriminator`` and ``BlurObservation``.
///
/// `@unchecked Sendable`: the only stored property is an immutable `VNCoreMLModel`, which
/// Vision allows to be shared across threads. (`VNCoreMLModel` itself just isn't annotated.)
internal final class CoreMLBlurPredictor: BlurPredicting, @unchecked Sendable {
    private struct MalformedModelError: Error { let reason: String }

    private let visionModel: VNCoreMLModel
    private let inputWidth: Int
    private let inputHeight: Int

    /// Loads the compiled model that ships in this framework's bundle.
    ///
    /// `BlurSegmentation` is the class Xcode generates from `BlurSegmentation.mlpackage`;
    /// its loader resolves `BlurSegmentation.mlmodelc` inside this framework's bundle,
    /// so there is no bundle/URL lookup to get wrong here.
    ///
    /// - Throws: ``BlurDiscriminatorError/modelLoadFailed(underlying:)`` if loading fails.
    init() async throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all  // CPU / GPU / Neural Engine

        do {
            let segmentation = try await BlurSegmentation.load(configuration: configuration)
            let mlModel = segmentation.model

            // Read the required input size from the model instead of hardcoding 224, so a
            // reconverted model with a different input size keeps working.
            guard let imageInput = mlModel.modelDescription.inputDescriptionsByName.values.first(where: { $0.type == .image }),
                  let constraint = imageInput.imageConstraint else {
                throw MalformedModelError(reason: "model has no image input constraint")
            }
            self.inputWidth = constraint.pixelsWide
            self.inputHeight = constraint.pixelsHigh
            self.visionModel = try VNCoreMLModel(for: mlModel)
        } catch {
            throw BlurDiscriminatorError.modelLoadFailed(underlying: error)
        }
    }

    func predict(input: CGImage) throws -> BlurObservation {
        // Letterbox to the model's input size so the model sees the same undistorted, black-padded
        // image it was trained on. Because the padded image already matches the input size, Vision's
        // `.scaleFill` is an identity resize and introduces no distortion of its own.
        guard let paddedInput = input.makeAspectFitPadded(width: inputWidth, height: inputHeight) else {
            throw BlurDiscriminatorError.imagePreprocessingFailed
        }

        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cgImage: paddedInput, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw BlurDiscriminatorError.inferenceFailed(underlying: error)
        }

        guard let observation = request.results?.first as? VNCoreMLFeatureValueObservation,
              let multiArray = observation.featureValue.multiArrayValue else {
            throw BlurDiscriminatorError.unexpectedOutput
        }

        return try makeObservation(from: multiArray,
                                   originalWidth: input.width,
                                   originalHeight: input.height)
    }

    private func makeObservation(from multiArray: MLMultiArray,
                                 originalWidth: Int,
                                 originalHeight: Int) throws -> BlurObservation {
        // The model outputs a 1xHxWx1 (NHWC) sigmoid map. Take the blur-map size from
        // the actual output tensor instead of hardcoding the model's current 224x224.
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count == 4, shape[0] == 1, shape[3] == 1 else {
            throw BlurDiscriminatorError.unexpectedOutput
        }
        let outputHeight = shape[1]
        let outputWidth = shape[2]

        let fullPixels = try grayscalePixels(from: multiArray, count: outputWidth * outputHeight)

        // Crop the padded region back out so the blur map matches the original image's aspect ratio.
        let cropped = BlurMapGeometry.croppedSize(outputWidth: outputWidth,
                                                  outputHeight: outputHeight,
                                                  originalWidth: originalWidth,
                                                  originalHeight: originalHeight)
        let pixels = BlurMapGeometry.cropTopLeft(fullPixels,
                                                 sourceWidth: outputWidth,
                                                 cropWidth: cropped.width,
                                                 cropHeight: cropped.height)

        guard let blurMap = BlurMapRenderer.makeBlurMap(grayscaledPixels: pixels,
                                                        width: cropped.width,
                                                        height: cropped.height) else {
            throw BlurDiscriminatorError.unexpectedOutput
        }
        return BlurObservation(blurMap: blurMap, grayscaledPixels: pixels)
    }

    /// Reads the sigmoid map without the per-element `multiArray[index]`
    /// subscript, which bridges an NSNumber for every one of the 50k pixels.
    /// The scoped buffer accessors replace the deprecated `dataPointer` and
    /// keep the pointer's lifetime bounded to the closure.
    private func grayscalePixels(from multiArray: MLMultiArray, count: Int) throws -> [UInt8] {
        switch multiArray.dataType {
        case .float32:
            return multiArray.withUnsafeBufferPointer(ofType: Float.self) {
                PixelConverter.floatToUInt8($0)
            }

        case .float16:
            // Widen to Float32 with vImage, then reuse vDSP. (Swift's `Float16`
            // is unavailable on x86_64, so go through raw bytes + vImage.)
            let floats = try multiArray.withUnsafeBytes { raw -> [Float] in
                var floats = [Float](repeating: 0, count: count)
                var source = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: raw.baseAddress),
                                           height: 1,
                                           width: vImagePixelCount(count),
                                           rowBytes: count * MemoryLayout<UInt16>.stride)
                let error = floats.withUnsafeMutableBytes { destinationRaw -> vImage_Error in
                    var destination = vImage_Buffer(data: destinationRaw.baseAddress,
                                                    height: 1,
                                                    width: vImagePixelCount(count),
                                                    rowBytes: count * MemoryLayout<Float>.stride)
                    return vImageConvert_Planar16FtoPlanarF(&source, &destination, vImage_Flags(kvImageNoFlags))
                }
                guard error == kvImageNoError else {
                    throw BlurDiscriminatorError.unexpectedOutput
                }
                return floats
            }
            return PixelConverter.floatToUInt8(floats)

        default:
            // Rare fallback (e.g. .double): slower NSNumber access, but correct.
            var floats = [Float](repeating: 0, count: count)
            for index in 0..<count {
                floats[index] = multiArray[index].floatValue
            }
            return PixelConverter.floatToUInt8(floats)
        }
    }
}
