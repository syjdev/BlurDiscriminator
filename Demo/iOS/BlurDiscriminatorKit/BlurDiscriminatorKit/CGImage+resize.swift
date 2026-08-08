//
//  CGImage+resize.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/07.
//

import CoreGraphics


extension CGImage {
    /// Returns a `width`×`height` image with `self` aspect-fit into the top-left corner and the
    /// remaining area padded with black.
    ///
    /// This reproduces the letterbox preprocessing the model was trained with: the aspect ratio is
    /// preserved (no stretching), and the padding is placed at the bottom/right so the content is
    /// top-left aligned. ``BlurMapGeometry`` later crops the model output back to this same region.
    func makeAspectFitPadded(width: Int, height: Int) -> CGImage? {
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

        // Context origin is bottom-left, so `y = height - scaledHeight` pins the content to the top.
        let drawRect = CGRect(x: 0,
                              y: CGFloat(height) - scaledHeight,
                              width: scaledWidth,
                              height: scaledHeight)

        context.interpolationQuality = .high
        context.draw(self, in: drawRect)

        return context.makeImage()
    }
}
