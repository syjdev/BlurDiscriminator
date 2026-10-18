// SPDX-License-Identifier: Apache-2.0
//
//  BlurObservation.swift
//  PixelBlurDetectorKit
//
//  Created by syjdev on 2021/11/03.
//

import CoreGraphics


/// The result of running ``PixelBlurDetector/predict(input:orientation:)`` on an image.
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

    /// How long each stage of the prediction took.
    public let timings: Timings

    internal init(blurMap: CGImage, grayscaledPixels: [UInt8], timings: Timings = .zero) {
        self.blurMap = blurMap
        self.grayscaledPixels = grayscaledPixels
        self.timings = timings
    }

    /// The fraction of pixels considered blurry.
    ///
    /// A pixel counts as blurry when its intensity in ``grayscaledPixels`` is strictly greater
    /// than `threshold`. Use the returned ratio to decide whether an image is blurry overall,
    /// e.g. treat it as blurry when the ratio exceeds some cutoff.
    ///
    /// - Parameter threshold: The intensity cutoff; higher values count fewer pixels as blurry.
    ///   Defaults to `127`, the midpoint of the intensity range.
    /// - Returns: A value in `0...1` — the number of blurry pixels divided by the total.
    public func blurRatio(threshold: UInt8 = 127) -> Float {
        let numberOfBlur = grayscaledPixels.count { $0 > threshold }
        return Float(numberOfBlur) / Float(grayscaledPixels.count)
    }
}


extension BlurObservation {
    /// Wall-clock durations of the stages of one ``PixelBlurDetector/predict(input:orientation:)``
    /// call, measured on the inference queue.
    ///
    /// Model loading, and the time a prediction waits for earlier ones to finish, are not included —
    /// measure the `predict` call itself to get the end-to-end latency.
    public struct Timings: Sendable, Equatable {
        /// Letterboxing the input (orientation, resampling, padding) into the model's input buffer.
        public let preprocessing: Duration
        /// The Core ML prediction itself.
        public let inference: Duration
        /// Cropping the model output back to the image's aspect ratio and building ``blurMap``.
        public let postprocessing: Duration

        /// The sum of all stages.
        public var total: Duration { preprocessing + inference + postprocessing }

        internal static let zero = Timings(preprocessing: .zero, inference: .zero, postprocessing: .zero)
    }
}
