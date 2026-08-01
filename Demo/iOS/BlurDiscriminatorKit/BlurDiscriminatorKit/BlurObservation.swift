//
//  BlurObservation.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/11/03.
//

import CoreGraphics


/// The result of running ``BlurDiscriminator/predict(input:)`` on an image.
///
/// A `BlurObservation` describes, per pixel, how blurry the analyzed image is. Pixel values
/// range from `0` (clear) to `255` (blurry), matched to the original image's dimensions.
public struct BlurObservation: Sendable {
    /// A grayscale blur map sized to the original image, where brighter pixels are blurrier.
    ///
    /// Suitable for direct display, e.g. `UIImage(cgImage: observation.blurMap)`.
    public let blurMap: CGImage

    /// The raw per-pixel blur intensities of ``blurMap``, from `0` (clear) to `255` (blurry),
    /// in row-major order.
    public let grayscaledPixels: [UInt8]

    internal init(blurMap: CGImage, grayscaledPixels: [UInt8]) {
        self.blurMap = blurMap
        self.grayscaledPixels = grayscaledPixels
    }

    /// The fraction of pixels considered blurry.
    ///
    /// A pixel counts as blurry when its intensity in ``grayscaledPixels`` is strictly greater
    /// than `threshold`. Use the returned ratio to decide whether an image is blurry overall,
    /// e.g. treat it as blurry when the ratio exceeds some cutoff.
    ///
    /// - Parameter threshold: The intensity cutoff in the range `0...255`; higher values count
    ///   fewer pixels as blurry.
    /// - Returns: A value in `0...1` — the number of blurry pixels divided by the total.
    public func blurRatio(threshold: Int) -> Float {
        let numberOfBlur = grayscaledPixels.count { $0 > threshold }
        return Float(numberOfBlur) / Float(grayscaledPixels.count)
    }
}
