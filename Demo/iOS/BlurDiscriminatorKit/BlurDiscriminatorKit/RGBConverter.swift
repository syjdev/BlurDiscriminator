//
//  RGBConverter.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/06.
//

import Foundation
import CoreGraphics


internal final class RGBConverter: InputConverter {
    private let inputWidth: Int
    private let inputHeight: Int
    
    
    internal init(inputWidth: Int, inputHeight: Int) {
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
    }
    
    
    internal func convert(cgImage: CGImage) -> Data? {
        guard let resized = cgImage.resize(width: inputWidth, height: inputHeight),
              let pixelBuffer = resized.makePixelBuffer()
        else {
            return nil
        }
        
        return pixelBuffer.makeData(byteCount: 3 * inputWidth * inputHeight)
    }
}
