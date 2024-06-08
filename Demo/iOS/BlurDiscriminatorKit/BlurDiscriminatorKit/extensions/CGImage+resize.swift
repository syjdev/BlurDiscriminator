//
//  CGImage+resize.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/07.
//

import Foundation
import CoreGraphics


extension CGImage {
    private func resize(width: Int, height: Int) -> CGImage? {
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
    
    func resizeWithPadding(width: Int, height: Int) -> CGImage? {
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        let sideLength = max(self.width, self.height)
        
        
        guard let context = CGContext(
            data: nil,
            width: sideLength,
            height: sideLength,
            bitsPerComponent: self.bitsPerComponent,
            bytesPerRow: self.bitsPerComponent * sideLength,
            space: self.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue)
        else {
            return nil
        }
        
        // 이미지 중심에 원본 이미지 그리기
        let originalSize = CGSize(width: self.width, height: self.height)
        let originalRect = CGRect(origin: CGPoint(x: 0, y: sideLength - Int(originalSize.height)), size: originalSize)
        context.draw(self, in: originalRect)
        
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        let paddingRects = [
            CGRect(x: 0, y: 0, width: sideLength, height: Int(originalRect.minY)),
            CGRect(x: Int(originalRect.maxX), y: 0, width: sideLength - Int(originalRect.maxX), height: sideLength)
        ]
        for rect in paddingRects {
            context.fill(rect)
        }
        
        return context.makeImage()?.resize(width: width, height: height)
    }
}
