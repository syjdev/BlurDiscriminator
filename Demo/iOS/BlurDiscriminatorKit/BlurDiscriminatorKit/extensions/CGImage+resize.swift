//
//  CGImage+resize.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/07.
//

import Foundation
import CoreGraphics


extension CGImage {
    func resize(width: Int, height: Int) -> CGImage? {
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        let size = CGSize(width: width, height: height)
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: self.bitsPerComponent,
            bytesPerRow: self.bytesPerRow,
            space: self.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue)
        
        context?.interpolationQuality = .high
        context?.draw(self, in: CGRect(origin:.zero, size:size))
        
        return context?.makeImage()
    }
}
