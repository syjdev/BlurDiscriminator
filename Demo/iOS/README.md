<div align = "center">
  <img src="https://img.shields.io/badge/iOS-16.2-0099FF?style=flat" />
  <img src="https://img.shields.io/badge/Swift-5-fb4e22?style=flat" />
  <img src="https://img.shields.io/badge/Core%20ML-float-BF53FF?style=flat" />
</div>

# Intro

__Demo/iOS__ is structured as follows. Open `iOS.xcworkspace` to work on both projects together.

- __BlurDiscriminatorKit__<br />
: Deep-learning based framework. It runs the bundled Core ML model (`BlurSegmentation.mlpackage`,
  compiled into the framework) on the CPU / GPU / Neural Engine. No model file or path has to be
  shipped separately.

- __demo__<br />
: Simple iOS demo app. Pick one of the CC0 sample images (or a photo from your library) and
  tap __Run__ to see its blur map, with a breakdown of where the time went — preprocessing, Core ML
  inference, postprocessing and scheduling overhead.

<br/>

# Usage

## Run the demo

Open `iOS.xcworkspace`, select the `demo` scheme and run. Tests live in the `BlurDiscriminatorKitTests`
scheme:

```bash
xcodebuild test -workspace iOS.xcworkspace -scheme BlurDiscriminatorKitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Add BlurDiscriminatorKit to your app

Either drag `BlurDiscriminatorKit/BlurDiscriminatorKit.xcodeproj` into your workspace and add
`BlurDiscriminatorKit.framework` to your target's __Frameworks, Libraries, and Embedded Content__
(_Embed & Sign_) — this is how the demo is set up — or build an XCFramework:

```bash
cd BlurDiscriminatorKit
for platform in "iOS" "iOS Simulator"; do
  xcodebuild archive -project BlurDiscriminatorKit.xcodeproj -scheme BlurDiscriminatorKit \
    -destination "generic/platform=$platform" -archivePath "build/$platform" SKIP_INSTALL=NO
done
xcodebuild -create-xcframework \
  -framework "build/iOS.xcarchive/Products/Library/Frameworks/BlurDiscriminatorKit.framework" \
  -framework "build/iOS Simulator.xcarchive/Products/Library/Frameworks/BlurDiscriminatorKit.framework" \
  -output build/BlurDiscriminatorKit.xcframework
```

and embed `build/BlurDiscriminatorKit.xcframework` the same way.

## API

```swift
import BlurDiscriminatorKit

let discriminator = BlurDiscriminator()

// Optional: load the model ahead of the first prediction (e.g. when the screen appears).
try await discriminator.prepare()

// Pass the raw CGImage and how it should be displayed; the rotation is applied while sampling.
let image: UIImage = ...
let observation = try await discriminator.predict(input: image.cgImage!,
                                                  orientation: CGImagePropertyOrientation(image.imageOrientation))

imageView.image = UIImage(cgImage: observation.blurMap)  // grayscale, brighter = blurrier
let isBlurry = observation.blurRatio() > 0.5             // fraction of pixels above 127

// Per-stage durations measured inside the framework (Swift `Duration`s).
print(observation.timings.preprocessing, observation.timings.inference, observation.timings.postprocessing)
```

`CGImagePropertyOrientation(_: UIImage.Orientation)` is not part of the SDK; see the small
extension at the bottom of [`demo/ViewController.swift`](demo/ViewController.swift).

- `BlurDiscriminator` is an actor; share one instance. Predictions run one at a time on a
  dedicated queue, never on the caller's thread.
- Any image size or aspect ratio is accepted. The image is letterboxed to the model's 224×224 input
  and the blur map is cropped back to the image's aspect ratio (in its displayed orientation).
- Errors are thrown as `BlurDiscriminatorError` (`modelLoadFailed`, `imagePreprocessingFailed`,
  `inferenceFailed`, `unexpectedOutput`).

<br/>

# License

- __Code__ — Apache-2.0 (see the repository root [`LICENSE`](../../LICENSE) and [`NOTICE`](../../NOTICE)).
- __`BlurSegmentation.mlpackage`__ — trained on the CUHK and DUT-DBD datasets;
  __research / non-commercial only__. See [`MODEL_LICENSE.md`](../../MODEL_LICENSE.md).
- __Sample images__ (`cc0_*`) — CC0 / public domain from Wikimedia Commons. See the [sample image credits](../../README.md#sample-image-credits).
