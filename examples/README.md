# Examples

Demo apps for the iOS and Android SDKs. Both have the same layout: pick one of the CC0 sample
images (or a photo of your own) and tap **Run** to see its blur map, with a breakdown of where the
time went — preprocessing, inference, postprocessing and scheduling overhead.

Each demo builds the SDK from this repository ([`ios/`](../ios), [`android/`](../android)), so
changes to the SDK show up in the demo right away.

## iOS

Open `ios/demo/demo.xcodeproj` in Xcode, select the `demo` scheme and run. The project adds the
repository root as a local Swift package, so it gets `PixelBlurDetectorKit` the same way an app
using the published package would.

```bash
xcodebuild build -project ios/demo/demo.xcodeproj -scheme demo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Android

Open `android/` in Android Studio and run the `app` configuration, or from the command line:

```bash
cd android
./gradlew :app:assembleDebug   # build the APK
./gradlew :app:installDebug    # install on a running device/emulator
```

Requires the Android SDK (platform 35, build-tools 34+) and JDK 17. The app depends on
`io.github.syjdev:pixel-blur-detector`, which Gradle resolves to [`../android`](../android) through a
composite build (`includeBuild` in `settings.gradle.kts`).

## License

- **Code** — Apache-2.0 (see the repository root [`LICENSE`](../LICENSE) and [`NOTICE`](../NOTICE)).
- **Sample images** (`cc0_*`) — CC0 / public domain from Wikimedia Commons. See the
  [sample image credits](../README.md#sample-image-credits).
- The demos bundle the SDKs' models, which are **research / non-commercial only** for now. See
  [`MODEL_LICENSE.md`](../MODEL_LICENSE.md).
