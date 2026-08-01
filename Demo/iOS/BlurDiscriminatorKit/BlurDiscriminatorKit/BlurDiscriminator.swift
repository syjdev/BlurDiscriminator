//
//  BlurDiscriminator.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/23.
//

import Foundation
import CoreGraphics
import BlurDiscriminatorKit.Private

/// A deep-learning based detector that classifies the clear and blurry regions of an image.
///
/// `BlurDiscriminator` wraps a quantized TensorFlow Lite segmentation model. Given a `CGImage`,
/// it produces a ``BlurObservation`` describing, per pixel, how blurry the input is.
///
/// The input image is resized to the model's fixed input size (224×224) internally, so any
/// image size may be passed. `BlurDiscriminator` is an actor: concurrent calls are serialized
/// by actor isolation, so a single instance is safe to share across concurrency domains.
///
/// ```swift
/// let discriminator = BlurDiscriminator(
///     modelPath: Bundle.main.path(forResource: "blur_segmentation_qat", ofType: "tflite")!,
///     numberOfThread: 2)
///
/// if let observation = await discriminator.predict(input: cgImage) {
///     imageView.image = UIImage(cgImage: observation.blurMap)
/// }
/// ```
public actor BlurDiscriminator {
    private let interpreter: InterpreterWrapper
    private let inputConverter: InputConverter = RGBConverter(inputWidth: Constants.inputWidth,
                                                              inputHeight: Constants.inputHeight)
    private let outputConverter: OutputConverter = GrayscaleConverter(inputWidth: Constants.inputWidth,
                                                                      inputHeight: Constants.inputHeight)

    /// Creates a discriminator backed by a TensorFlow Lite model.
    ///
    /// - Parameters:
    ///   - modelPath: The file system path to the `.tflite` model. Typically obtained from the
    ///     app bundle, e.g. `Bundle.main.path(forResource: "blur_segmentation_qat", ofType: "tflite")`.
    ///   - numberOfThread: The number of threads the interpreter may use for inference.
    public init(modelPath: String, numberOfThread: UInt8) {
        interpreter = InterpreterWrapper(modelPath: modelPath, andNumberOfThread: numberOfThread)
    }

    /// Runs blur detection on the given image.
    ///
    /// Inference is actor-isolated: concurrent calls are executed one at a time, and the
    /// calling task is suspended (not blocked) until inference completes.
    ///
    /// - Parameter input: The image to analyze. It is resized to the model input size internally.
    /// - Returns: A ``BlurObservation`` describing the blur map, or `nil` if the input could not
    ///   be converted or inference failed.
    public func predict(input: CGImage) -> BlurObservation? {
        guard let convertedData = inputConverter.convert(cgImage: input),
              let outputData = interpreter.interpret(withInputData: convertedData)
        else {
            return nil
        }

        return outputConverter.convert(data: outputData,
                                       originImageWidth: input.width,
                                       originImageHeight: input.height)
    }
}
