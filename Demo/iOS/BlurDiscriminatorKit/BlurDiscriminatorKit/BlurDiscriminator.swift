//
//  BlurDiscriminator.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/23.
//

import Foundation
import CoreGraphics
import BlurDiscriminatorKit.Private


public final class BlurDiscriminator {
    private let _interpreter: InterpreterWrapper
    private let inputConverter: InputConverter = RGBConverter(inputWidth: Constants.inputWidth,
                                                              inputHeight: Constants.inputHeight)
    private let outputConverter: OutputConverter = GrayscaleConverter(inputWidth: Constants.inputWidth,
                                                                      inputHeight: Constants.inputHeight)
    
    
    public init(modelPath: String, numberOfThread: UInt8) {
        _interpreter = InterpreterWrapper(modelPath: modelPath, andNumberOfThread: numberOfThread)
    }
    
    
    public func predict(input: CGImage) -> BlurObservation? {
        guard let outputData = self.interpret(input: input) else { return nil }
        return self.outputConverter.convert(data: outputData)
    }
    
    
    internal func interpret(input: CGImage) -> Data? {
        guard let convertedData = inputConverter.convert(cgImage: input) else {
            return nil
        }
        
        return _interpreter.interpret(withInputData: convertedData)
    }
}
