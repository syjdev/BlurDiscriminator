// SPDX-License-Identifier: Apache-2.0
//
//  PixelBlurDetector.swift
//  PixelBlurDetectorKit
//
//  Created by syjdev on 2021/09/23.
//

import CoreGraphics
import Foundation
import ImageIO

/// An error thrown by ``PixelBlurDetector/predict(input:orientation:)``.
public enum PixelBlurDetectorError: Error {
    /// The Core ML model failed to load from the package's resource bundle.
    case modelLoadFailed(underlying: Error)
    /// The input image could not be prepared (letterboxed) for the model.
    case imagePreprocessingFailed
    /// The Core ML prediction failed.
    case inferenceFailed(underlying: Error)
    /// The model produced an output the SDK does not understand.
    case unexpectedOutput
}

/// What ``PixelBlurDetector`` needs from its inference engine — a seam for
/// injecting a test double in place of the Core ML-backed predictor.
internal protocol BlurPredicting: Sendable {
    func predict(input: CGImage, orientation: CGImagePropertyOrientation) async throws -> BlurObservation
}

/// A deep-learning based detector that classifies the clear and blurry regions of an image.
///
/// `PixelBlurDetector` wraps a Core ML segmentation model (`BlurSegmentation.mlpackage`, bundled
/// with this package). Given a `CGImage`, it produces a ``BlurObservation`` describing, per
/// pixel, how blurry the input is.
///
/// The input image is letterboxed to the model's fixed input size (currently 224×224) internally —
/// aspect ratio is preserved with black padding — and the resulting blur map is cropped back to the
/// original image's aspect ratio. Any image size may be passed. Pass the photo's orientation and the
/// rotation is applied while sampling — there is no need to redraw the image upright first.
///
/// `PixelBlurDetector` is an actor, so a single instance is safe to share across concurrency
/// domains. Predictions run one at a time on a dedicated queue, never on the caller's thread.
///
/// ```swift
/// let detector = PixelBlurDetector()
/// try await detector.prepare()  // optional: load the model ahead of the first prediction
///
/// let observation = try await detector.predict(input: cgImage, orientation: .right)
/// imageView.image = UIImage(cgImage: observation.blurMap)
/// ```
public actor PixelBlurDetector {
    private let loadPredictor: @Sendable () async throws -> any BlurPredicting
    private var predictor: (any BlurPredicting)?
    private var loadTask: Task<any BlurPredicting, Error>?

    /// Creates a detector backed by the bundled Core ML model.
    ///
    /// Creation is cheap: the model is loaded lazily on the first call to ``predict(input:orientation:)``
    /// (or ``prepare()``), so initializing the detector never blocks the calling thread.
    public init() {
        self.loadPredictor = { try await CoreMLBlurPredictor() }
    }

    /// Test seam: creates a detector that loads its predictor from the given closure.
    internal init(loadPredictor: @escaping @Sendable () async throws -> any BlurPredicting) {
        self.loadPredictor = loadPredictor
    }

    /// Loads the Core ML model now instead of on the first ``predict(input:orientation:)``.
    ///
    /// Optional: call it early — e.g. when the screen that will run predictions appears — so the
    /// first prediction doesn't also pay for loading the model. Calling it more than once, or
    /// concurrently with `predict`, never loads the model twice.
    ///
    /// - Throws: ``PixelBlurDetectorError/modelLoadFailed(underlying:)`` if the model could not be
    ///   loaded. A failed load is not cached, so a later call may retry.
    public func prepare() async throws {
        _ = try await loadedPredictor()
    }

    /// Runs blur detection on the given image.
    ///
    /// The Core ML model is loaded on the first call (unless ``prepare()`` already did) and cached
    /// for subsequent calls. Concurrent calls are executed one at a time on a dedicated queue; the
    /// calling task is suspended (not blocked) until inference completes.
    ///
    /// - Parameters:
    ///   - input: The image to analyze, as stored (raw pixel order). It is resized to the model
    ///     input size internally.
    ///   - orientation: How `input` should be displayed — e.g. the EXIF orientation of a photo, or
    ///     `UIImage.imageOrientation` converted to `CGImagePropertyOrientation`. Defaults to `.up`.
    /// - Returns: A ``BlurObservation`` describing the blur map, in the displayed orientation
    ///   (a `.right` photo yields a portrait blur map).
    /// - Throws: ``PixelBlurDetectorError`` if the model could not be loaded, inference failed,
    ///   or the model produced an unexpected output.
    public func predict(input: CGImage,
                        orientation: CGImagePropertyOrientation = .up) async throws -> BlurObservation {
        return try await loadedPredictor().predict(input: input, orientation: orientation)
    }

    /// Returns the cached predictor, loading the model on first use. A single in-flight load
    /// task is shared between reentrant callers so the model is never loaded twice; a failed
    /// load is not cached, so a later call may retry.
    private func loadedPredictor() async throws -> any BlurPredicting {
        if let predictor {
            return predictor
        }
        if let loadTask {
            return try await loadTask.value
        }

        let task = Task { [loadPredictor] in try await loadPredictor() }
        loadTask = task
        defer { loadTask = nil }

        let loaded = try await task.value
        predictor = loaded
        return loaded
    }
}
