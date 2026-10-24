# Examples

Demo apps for the iOS and Android SDKs. Both have the same layout: pick one of the CC0 sample
images (or a photo of your own) and tap **Run** to see its blur map, with a breakdown of where the
time went — preprocessing, inference, postprocessing and scheduling overhead.

Each demo depends on the published SDK, the same way your app would:
[PixelBlurDetector-iOS](https://github.com/syjdev/PixelBlurDetector-iOS) through Swift Package
Manager and [PixelBlurDetector-Android](https://github.com/syjdev/PixelBlurDetector-Android)
(`io.github.syjdev:pixel-blur-detector`) from Maven Central. Each section below shows how to build
a demo against a local checkout of the SDK instead.

## iOS

Open `ios/demo/demo.xcodeproj` in Xcode, select the `demo` scheme and run. Xcode fetches
`PixelBlurDetectorKit` from `https://github.com/syjdev/PixelBlurDetector-iOS` (3.0.0 up to the next
major version).

```bash
xcodebuild build -project ios/demo/demo.xcodeproj -scheme demo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

To try local changes to the SDK, drag your clone of `PixelBlurDetector-iOS` from Finder into the
project navigator. Xcode then uses the local package instead of the remote one, without changing
the project file. Remove it from the navigator to switch back.

## Android

Open `android/` in Android Studio and run the `app` configuration, or from the command line:

```bash
cd android
./gradlew :app:assembleDebug   # build the APK
./gradlew :app:installDebug    # install on a running device/emulator
```

Requires the Android SDK (platform 35, build-tools 34+) and JDK 17. The app depends on
`io.github.syjdev:pixel-blur-detector:3.0.0` from Maven Central.

To try local changes to the SDK, pass the path of your `PixelBlurDetector-Android` clone. Gradle then
builds the SDK from that checkout (a composite build) instead of downloading it. With both
repositories cloned side by side:

```bash
./gradlew :app:assembleDebug -PpixelBlurDetectorSdkPath=../../../PixelBlurDetector-Android
```

In Android Studio, put `pixelBlurDetectorSdkPath=<absolute path>` in `~/.gradle/gradle.properties`
instead, and remove it to switch back.

## License

- **Code** — Apache-2.0 (see the repository root [`LICENSE`](../LICENSE) and [`NOTICE`](../NOTICE)).
- **Sample images** (`cc0_*`) — CC0 / public domain from Wikimedia Commons. See the
  [sample image credits](../README.md#sample-image-credits).
- The demos include the SDKs' models, which are **research / non-commercial only** for now. See
  [`MODEL_LICENSE.md`](../MODEL_LICENSE.md).
