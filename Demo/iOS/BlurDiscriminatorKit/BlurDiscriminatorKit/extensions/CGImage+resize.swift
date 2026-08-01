//
//  CGImage+resize.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/07.
//

import Foundation
import CoreGraphics


extension CGImage {
    func makeAspectFitPaddedContext(width: Int, height: Int) -> CGContext? {
        guard self.width > 0, self.height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        else {
            return nil
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let scale = min(CGFloat(width) / CGFloat(self.width),
                        CGFloat(height) / CGFloat(self.height))
        let scaledWidth = CGFloat(self.width) * scale
        let scaledHeight = CGFloat(self.height) * scale

        let drawRect = CGRect(x: 0,
                              y: CGFloat(height) - scaledHeight,
                              width: scaledWidth,
                              height: scaledHeight)

        context.interpolationQuality = .high
        context.draw(self, in: drawRect)

        return context
    }
}
