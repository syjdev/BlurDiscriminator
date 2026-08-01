//
//  BlurDiscriminator.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/23.
//

import Foundation
import CoreGraphics
import BlurDiscriminatorKit.Private

public final class BlurDiscriminator: @unchecked Sendable {
    private let interpreter: InterpreterWrapper
    private let inputConverter: InputConverter = RGBConverter(inputWidth: Constants.inputWidth,
                                                              inputHeight: Constants.inputHeight)
    private let outputConverter: OutputConverter = GrayscaleConverter(inputWidth: Constants.inputWidth,
                                                                      inputHeight: Constants.inputHeight)

    private let inferenceQueue = DispatchQueue(label: "com.blurdiscriminatorkit.inference", qos: .userInitiated)

    public init(modelPath: String, numberOfThread: UInt8) {
        interpreter = InterpreterWrapper(modelPath: modelPath, andNumberOfThread: numberOfThread)
    }

    public func predict(input: CGImage) -> BlurObservation? {
        return inferenceQueue.sync { runPrediction(input: input) }
    }

    public func predict(input: CGImage) async -> BlurObservation? {
        return await withCheckedContinuation { continuation in
            inferenceQueue.async { [self] in
                continuation.resume(returning: runPrediction(input: input))
            }
        }
    }

    private func runPrediction(input: CGImage) -> BlurObservation? {
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
