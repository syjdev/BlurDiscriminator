# PixelBlurDetector for Android

The Android SDK, with an API that mirrors the iOS `PixelBlurDetectorKit`. It runs the **float**
TensorFlow Lite model (`blur_segmentation_float.tflite`) to detect blurry regions
of an image. This is the **same float model** the iOS Core ML path runs, so both platforms
produce matching blur maps.

## Module

**`pixel-blur-detector/`** — Android library (AAR). Public API mirrors the iOS `PixelBlurDetectorKit`:

  - `PixelBlurDetector(context)` — `suspend fun predict(input: Bitmap, orientation: ImageOrientation = UP): BlurObservation`
    (serialized with a `Mutex`, runs on `Dispatchers.Default`, model loaded lazily — mirrors the iOS `actor`).
    `suspend fun prepare()` loads the model ahead of the first prediction.
  - `ImageOrientation` — the photo's EXIF orientation (`ImageOrientation.fromExif(...)`), mirroring iOS's
    `CGImagePropertyOrientation`. `BitmapFactory` ignores EXIF; pass the orientation and the rotation is
    applied while sampling, and the blur map comes back in the displayed orientation.
  - `BlurObservation` — `blurMap: Bitmap`, `grayscaledPixels: ByteArray`, `blurRatio(threshold = 127)`, and
    `timings` (preprocessing / inference / postprocessing as `kotlin.time.Duration`).
  - `PixelBlurDetectorException` — `ModelLoadFailed` / `ImagePreprocessingFailed` / `InferenceFailed`.
  - Internals: `TFLiteBlurPredictor` (interpreter), `ImagePreprocessor` (letterbox + bilinear resample), `BlurMap` (crop-back + grayscale).
  - The model ships in `src/main/assets/`.

The demo app lives in [`examples/android`](../examples/android); see [`examples/README.md`](../examples/README.md).

## Preprocessing parity with iOS

The model was trained with **letterbox** preprocessing, so the pipeline matches iOS exactly:

1. **Input** — aspect-fit the bitmap into 224×224 with black padding, content top-left aligned
   (`ImagePreprocessor.letterboxRgb`), then feed float32 RGB normalized to `[0, 1]`. The resize is a
   half-pixel bilinear resampler ported line by line from iOS (not `Canvas` filtering), so the same
   pixels produce a bit-identical model input on both platforms. The content size is rounded to whole
   pixels (`BlurMapGeometry.contentSize`) and shared with the crop-back below.
2. **Output** — the 224×224 float32 sigmoid map is scaled to 8-bit and cropped back to the original
   image's aspect ratio (`BlurMapGeometry`) so the blur map isn't distorted.

## Build & test

Requires the Android SDK (platform 35, build-tools 34+) and JDK 17.

```bash
cd android
# local.properties with sdk.dir is created on first Android Studio open,
# or export ANDROID_HOME=/path/to/Android/sdk
./gradlew :pixel-blur-detector:testDebugUnitTest   # run the unit tests
./gradlew :pixel-blur-detector:assembleRelease     # build the AAR
```

Or open `android/` in Android Studio.

## License

- **Code** — Apache-2.0 (see the repository root [`LICENSE`](../LICENSE) and [`NOTICE`](../NOTICE)).
- **`blur_segmentation_float.tflite`** — trained on the CUHK and DUT-DBD datasets, neither of which
  states a license; **research / non-commercial only** for now. See root [`MODEL_LICENSE.md`](../MODEL_LICENSE.md).