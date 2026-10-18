<div align = "center">
  <img src="https://img.shields.io/badge/iOS-16.2-0099FF?style=flat" />
  <img src="https://img.shields.io/badge/Swift-5-fb4e22?style=flat" />
  <img src="https://img.shields.io/badge/Core%20ML-float-BF53FF?style=flat" />
</div>

# PixelBlurDetectorKit for iOS

__PixelBlurDetectorKit__ is the iOS SDK. It runs the bundled Core ML model
(`BlurSegmentation.mlpackage`, compiled into the package's resource bundle) on the CPU / GPU /
Neural Engine. No model file or path has to be shipped separately.

- `PixelBlurDetectorKit/`: SDK sources and the Core ML model
- `PixelBlurDetectorKitTests/`: unit tests (CC0 test images in `resources/`)

The Swift package manifest is [`Package.swift`](../Package.swift) at the repository root.

The demo app lives in [`examples/ios`](../examples/ios); see [`examples/README.md`](../examples/README.md).

<br/>

# Usage

## Add PixelBlurDetectorKit to your app

In Xcode, choose __File › Add Package Dependencies…__ and enter
`https://github.com/syjdev/PixelBlurDetector`, or add it to your `Package.swift`:

```swift
.package(url: "https://github.com/syjdev/PixelBlurDetector.git", from: "3.0.0"),
// in your target's dependencies:
.product(name: "PixelBlurDetectorKit", package: "PixelBlurDetector"),
```

The Core ML model is compiled into the package's resource bundle; nothing else has to be shipped.

## Run the tests

From the repository root:

```bash
xcodebuild test -scheme PixelBlurDetector \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## API

```swift
import PixelBlurDetectorKit

let detector = PixelBlurDetector()

// Optional: load the model ahead of the first prediction (e.g. when the screen appears).
try await detector.prepare()

// Pass the raw CGImage and how it should be displayed; the rotation is applied while sampling.
let image: UIImage = ...
let observation = try await detector.predict(input: image.cgImage!,
                                             orientation: CGImagePropertyOrientation(image.imageOrientation))

imageView.image = UIImage(cgImage: observation.blurMap)  // grayscale, brighter = blurrier
let isBlurry = observation.blurRatio() > 0.5             // fraction of pixels above 127

// Per-stage durations measured inside the SDK (Swift `Duration`s).
print(observation.timings.preprocessing, observation.timings.inference, observation.timings.postprocessing)
```

`CGImagePropertyOrientation(_: UIImage.Orientation)` is not part of the SDK; see the small
extension at the bottom of [`examples/ios/demo/ViewController.swift`](../examples/ios/demo/ViewController.swift).

- `PixelBlurDetector` is an actor; share one instance. Predictions run one at a time on a
  dedicated queue, never on the caller's thread.
- Any image size or aspect ratio is accepted. The image is letterboxed to the model's 224×224 input
  and the blur map is cropped back to the image's aspect ratio (in its displayed orientation).
- Errors are thrown as `PixelBlurDetectorError` (`modelLoadFailed`, `imagePreprocessingFailed`,
  `inferenceFailed`, `unexpectedOutput`).

<br/>

# License

- __Code__ — Apache-2.0 (see the repository root [`LICENSE`](../LICENSE) and [`NOTICE`](../NOTICE)).
- __`BlurSegmentation.mlpackage`__ — trained on the CUHK and DUT-DBD datasets, neither of which
  states a license; __research / non-commercial only__ for now. See [`MODEL_LICENSE.md`](../MODEL_LICENSE.md).
- __Test images__ (`cc0_*`) — CC0 / public domain from Wikimedia Commons. See the [sample image credits](../README.md#sample-image-credits).
