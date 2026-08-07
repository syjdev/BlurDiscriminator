//
//  BlurDiscriminator.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/23.
//

import CoreGraphics
import Foundation

/// An error thrown by ``BlurDiscriminator/predict(input:)``.
public enum BlurDiscriminatorError: Error {
    /// The Core ML model failed to load from the framework bundle.
    case modelLoadFailed(underlying: Error)
    /// The Vision request failed while running the model.
    case inferenceFailed(underlying: Error)
    /// The model produced an output the framework does not understand.
    case unexpectedOutput
}

/// What ``BlurDiscriminator`` needs from its inference engine — a seam for
/// injecting a test double in place of the Core ML-backed predictor.
internal protocol BlurPredicting: Sendable {
    func predict(input: CGImage) throws -> BlurObservation
}

/// A deep-learning based detector that classifies the clear and blurry regions of an image.
///
/// `BlurDiscriminator` wraps a Core ML segmentation model (`BlurSegmentation.mlpackage`, bundled
/// inside this framework). Given a `CGImage`, it produces a ``BlurObservation`` describing, per
/// pixel, how blurry the input is.
///
/// The input image is resized to the model's fixed input size (currently 224×224) internally,
/// so any image size may be passed. `BlurDiscriminator` is an actor: concurrent calls are
/// serialized by actor isolation, so a single instance is safe to share across concurrency
/// domains.
///
/// ```swift
/// let discriminator = BlurDiscriminator()
///
/// let observation = try await discriminator.predict(input: cgImage)
/// imageView.image = UIImage(cgImage: observation.blurMap)
/// ```
public actor BlurDiscriminator {
    private let loadPredictor: @Sendable () async throws -> any BlurPredicting
    private var predictor: (any BlurPredicting)?
    private var loadTask: Task<any BlurPredicting, Error>?

    /// Creates a discriminator backed by the bundled Core ML model.
    ///
    /// Creation is cheap: the model is loaded lazily on the first call to ``predict(input:)``,
    /// so initializing the discriminator never blocks the calling thread.
    public init() {
        self.loadPredictor = { try await CoreMLBlurPredictor() }
    }

    /// Test seam: creates a discriminator that loads its predictor from the given closure.
    internal init(loadPredictor: @escaping @Sendable () async throws -> any BlurPredicting) {
        self.loadPredictor = loadPredictor
    }

    /// Runs blur detection on the given image.
    ///
    /// The Core ML model is loaded on the first call and cached for subsequent calls.
    /// Inference is actor-isolated: concurrent calls are executed one at a time, and the
    /// calling task is suspended (not blocked) until inference completes.
    ///
    /// - Parameter input: The image to analyze. It is resized to the model input size internally.
    /// - Returns: A ``BlurObservation`` describing the blur map.
    /// - Throws: ``BlurDiscriminatorError`` if the model could not be loaded, inference failed,
    ///   or the model produced an unexpected output.
    public func predict(input: CGImage) async throws -> BlurObservation {
        return try await loadedPredictor().predict(input: input)
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
