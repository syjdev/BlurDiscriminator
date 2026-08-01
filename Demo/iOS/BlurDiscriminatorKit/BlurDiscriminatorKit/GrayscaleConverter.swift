//
//  GrayscaleConverter.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/11/03.
//

import Foundation
import CoreGraphics


internal final class GrayscaleConverter: OutputConverter {
    private let inputWidth: Int
    private let inputHeight: Int

    internal init(inputWidth: Int, inputHeight: Int) {
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
    }

    func convert(data: Data, originImageWidth: Int, originImageHeight: Int) -> BlurObservation? {
        // The uint8 model emits one byte per pixel (sigmoid output, scale 1/256),
        // which maps directly onto an 8-bit grayscale image.
        guard data.count >= inputWidth * inputHeight,
              originImageWidth > 0, originImageHeight > 0
        else {
            return nil
        }

        let pixels = [UInt8](data.prefix(inputWidth * inputHeight))

        let cropWidth: Int
        let cropHeight: Int
        if originImageWidth > originImageHeight {
            cropWidth = inputWidth
            cropHeight = Int(Float(inputHeight) * Float(originImageHeight) / Float(originImageWidth))
        } else if originImageWidth < originImageHeight {
            cropWidth = Int(Float(inputWidth) * Float(originImageWidth) / Float(originImageHeight))
            cropHeight = inputHeight
        } else {
            cropWidth = inputWidth
            cropHeight = inputHeight
        }

        let croppedPixels = cropPixels(pixels, cropWidth: cropWidth, cropHeight: cropHeight)

        guard let blurMap = makeGrayscaleImage(pixels: croppedPixels, width: cropWidth, height: cropHeight) else {
            return nil
        }

        return BlurObservation(blurMap: blurMap, grayscaledPixels: croppedPixels)
    }

    private func cropPixels(_ pixels: [UInt8], cropWidth: Int, cropHeight: Int) -> [UInt8] {
        guard cropWidth != inputWidth || cropHeight != inputHeight else { return pixels }

        var cropped = [UInt8]()
        cropped.reserveCapacity(cropWidth * cropHeight)
        for row in 0..<cropHeight {
            let rowStart = row * inputWidth
            cropped.append(contentsOf: pixels[rowStart..<(rowStart + cropWidth)])
        }
        return cropped
    }

    private func makeGrayscaleImage(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0,
              let dataProvider = CGDataProvider(data: Data(pixels) as CFData)
        else {
            return nil
        }

        return CGImage(width: width,
                       height: height,
                       bitsPerComponent: 8,
                       bitsPerPixel: 8,
                       bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: dataProvider,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}
