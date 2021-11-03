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
    public lazy var blurRatio: Float = {
        let numberOfBlur: Float = grayscaledPixels.reduce(into: 0) { result, element in
            if element > 127 {
                result += 1
            }
        }
        
        return numberOfBlur / Float(grayscaledPixels.count)
    }()
    
    internal init(blurMap: CGImage,
                  grayscaledPixels: [UInt8]) {
        self.blurMap = blurMap
        self.grayscaledPixels = grayscaledPixels
    }
}
