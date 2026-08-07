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
    private let visionModel: VNCoreMLModel

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
            self.visionModel = try VNCoreMLModel(for: segmentation.model)
        } catch {
            throw BlurDiscriminatorError.modelLoadFailed(underlying: error)
        }
    }

    func predict(input: CGImage) throws -> BlurObservation {
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFill  // match training: no aspect crop

        let handler = VNImageRequestHandler(cgImage: input, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw BlurDiscriminatorError.inferenceFailed(underlying: error)
        }

        guard let observation = request.results?.first as? VNCoreMLFeatureValueObservation,
              let multiArray = observation.featureValue.multiArrayValue else {
            throw BlurDiscriminatorError.unexpectedOutput
        }

        return try makeObservation(from: multiArray)
    }

    private func makeObservation(from multiArray: MLMultiArray) throws -> BlurObservation {
        // The model outputs a 1xHxWx1 (NHWC) sigmoid map. Take the blur-map size from
        // the actual output tensor instead of hardcoding the model's current 224x224,
        // so a reconverted model with a different input size keeps working.
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count == 4, shape[0] == 1, shape[3] == 1 else {
            throw BlurDiscriminatorError.unexpectedOutput
        }
        let height = shape[1]
        let width = shape[2]

        let pixels = try grayscalePixels(from: multiArray, count: width * height)
        guard let blurMap = BlurMapRenderer.makeBlurMap(grayscaledPixels: pixels,
                                                        width: width,
                                                        height: height) else {
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
