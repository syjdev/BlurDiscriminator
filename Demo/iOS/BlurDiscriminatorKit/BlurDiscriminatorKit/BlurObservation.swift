//
//  BlurObservation.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/11/03.
//

import Foundation
import CoreGraphics


public final class BlurObservation {
    public let blurMap: CGImage
    public let grayscaledPixels: [UInt8]
    public let data: Data

    internal init(blurMap: CGImage,
                  grayscaledPixels: [UInt8],
                  data: Data = Data()) {
        self.blurMap = blurMap
        self.grayscaledPixels = grayscaledPixels
        self.data = data
    }
    
    public func blurRatio(threshold: Int) -> Float {
        let numberOfBlur: Float = grayscaledPixels.reduce(into: 0) { result, element in
            if element > threshold {
                result += 1
            }
        }
        
        return numberOfBlur / Float(grayscaledPixels.count)
    }
}
