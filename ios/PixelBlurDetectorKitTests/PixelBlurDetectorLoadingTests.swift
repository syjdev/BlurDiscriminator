//
//  PixelBlurDetectorLoadingTests.swift
//  PixelBlurDetectorKitTests
//
//  Unit tests for PixelBlurDetector's lazy predictor loading, using an injected
//  test double instead of the real Core ML model.
//

import XCTest
import CoreGraphics
import ImageIO
@testable import PixelBlurDetectorKit


class PixelBlurDetectorLoadingTests: XCTestCase {
    private struct StubError: Error {}

    /// A predictor double that returns a fixed observation.
    private final class PredictorStub: BlurPredicting, @unchecked Sendable {
        let observation: BlurObservation

        init(observation: BlurObservation) {
            self.observation = observation
        }

        func predict(input: CGImage, orientation: CGImagePropertyOrientation) throws -> BlurObservation {
            return observation
        }
    }

    /// Counts loader invocations; lock-guarded because the loader closure is `@Sendable`.
    private final class LoadRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        func increment() -> Int {
            lock.lock(); defer { lock.unlock() }
            count += 1
            return count
        }

        var loadCount: Int {
            lock.lock(); defer { lock.unlock() }
            return count
        }
    }


    func test_predictor_is_loaded_once_and_cached() async throws {
        let observation = try XCTUnwrap(Self.makeObservation())
        let recorder = LoadRecorder()
        let detector = PixelBlurDetector(loadPredictor: {
            _ = recorder.increment()
            return PredictorStub(observation: observation)
        })
        let input = try XCTUnwrap(Self.makeGrayImage(width: 1, height: 1))

        let first = try await detector.predict(input: input)
        let second = try await detector.predict(input: input)

        XCTAssertEqual(recorder.loadCount, 1, "the predictor should be loaded once and cached")
        XCTAssertEqual(first.grayscaledPixels, observation.grayscaledPixels)
        XCTAssertEqual(second.grayscaledPixels, observation.grayscaledPixels)
    }


    func test_failed_load_is_not_cached_and_can_be_retried() async throws {
        let observation = try XCTUnwrap(Self.makeObservation())
        let recorder = LoadRecorder()
        let detector = PixelBlurDetector(loadPredictor: {
            if recorder.increment() == 1 {
                throw StubError()
            }
            return PredictorStub(observation: observation)
        })
        let input = try XCTUnwrap(Self.makeGrayImage(width: 1, height: 1))

        do {
            _ = try await detector.predict(input: input)
            XCTFail("the first predict should rethrow the load failure")
        } catch is StubError {
            // expected: the load failure reaches the caller
        }

        let recovered = try await detector.predict(input: input)

        XCTAssertEqual(recorder.loadCount, 2, "a failed load should not be cached")
        XCTAssertEqual(recovered.grayscaledPixels, observation.grayscaledPixels)
    }


    func test_prepare_loads_the_predictor_ahead_of_predict() async throws {
        let observation = try XCTUnwrap(Self.makeObservation())
        let recorder = LoadRecorder()
        let detector = PixelBlurDetector(loadPredictor: {
            _ = recorder.increment()
            return PredictorStub(observation: observation)
        })
        let input = try XCTUnwrap(Self.makeGrayImage(width: 1, height: 1))

        try await detector.prepare()
        XCTAssertEqual(recorder.loadCount, 1, "prepare should load the predictor")

        try await detector.prepare()
        _ = try await detector.predict(input: input)
        XCTAssertEqual(recorder.loadCount, 1, "prepare and predict should reuse the loaded predictor")
    }


    // MARK: - fixtures

    private static func makeObservation() -> BlurObservation? {
        guard let blurMap = makeGrayImage(width: 1, height: 1) else { return nil }
        return BlurObservation(blurMap: blurMap, grayscaledPixels: [255])
    }

    private static func makeGrayImage(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return nil
        }
        return context.makeImage()
    }
}
