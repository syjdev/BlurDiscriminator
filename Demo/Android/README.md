# BlurDiscriminator — Android Demo

An Android port of the iOS demo, with a near-identical API. It runs the **float**
TensorFlow Lite model (`blur_segmentation_float.tflite`) to detect blurry regions
of an image. This is the **same float model** the iOS Core ML path runs (converted
from the same `saved_model/blur_discriminate_float`), so both platforms produce
matching blur maps — unlike the uint8 QAT model, whose quantization biases the map
darker.

## Modules

- **`blurdiscriminatorkit/`** — Android library (AAR). Public API mirrors the iOS `BlurDiscriminatorKit`:
  - `BlurDiscriminator(context)` — `suspend fun predict(input: Bitmap, orientation: ImageOrientation = UP): BlurObservation`
    (serialized with a `Mutex`, runs on `Dispatchers.Default`, model loaded lazily — mirrors the iOS `actor`).
    `suspend fun prepare()` loads the model ahead of the first prediction.
  - `ImageOrientation` — the photo's EXIF orientation (`ImageOrientation.fromExif(...)`), mirroring iOS's
    `CGImagePropertyOrientation`. `BitmapFactory` ignores EXIF; pass the orientation and the rotation is
    applied while sampling, and the blur map comes back in the displayed orientation.
  - `BlurObservation` — `blurMap: Bitmap`, `grayscaledPixels: ByteArray`, `blurRatio(threshold = 127)`, and
    `timings` (preprocessing / inference / postprocessing as `kotlin.time.Duration`).
  - `BlurDiscriminatorException` — `ModelLoadFailed` / `ImagePreprocessingFailed` / `InferenceFailed`.
  - Internals: `TFLiteBlurPredictor` (interpreter), `ImagePreprocessor` (letterbox + bilinear resample), `BlurMap` (crop-back + grayscale).
  - The model ships in `src/main/assets/`.
- **`app/`** — demo app, laid out like the iOS demo: pick one of the CC0 sample images (or a photo
  from the system photo picker) and tap **Run** to see its blur map, with a breakdown of where the time
  went — preprocessing, TensorFlow Lite inference, postprocessing and scheduling overhead.

## Preprocessing parity with iOS

The model was trained with **letterbox** preprocessing, so the pipeline matches iOS exactly:

1. **Input** — aspect-fit the bitmap into 224×224 with black padding, content top-left aligned
   (`ImagePreprocessor.letterboxRgb`), then feed float32 RGB normalized to `[0, 1]`. The resize is a
   half-pixel bilinear resampler ported line by line from iOS (not `Canvas` filtering), so the same
   pixels produce a bit-identical model input on both platforms. The content size is rounded to whole
   pixels (`BlurMapGeometry.contentSize`) and shared with the crop-back below.
2. **Output** — the 224×224 float32 sigmoid map is scaled to 8-bit and cropped back to the original
   image's aspect ratio (`BlurMapGeometry`) so the blur map isn't distorted.

## Build & run

Requires the Android SDK (platform 35, build-tools 34+) and JDK 17.

```bash
cd Demo/Android
# local.properties with sdk.dir is created on first Android Studio open,
# or export ANDROID_HOME=/path/to/Android/sdk
./gradlew :app:assembleDebug          # build the APK
./gradlew :app:installDebug           # install on a running device/emulator
```

Or just open `Demo/Android/` in Android Studio and Run.

## License

- **Code** — Apache-2.0 (see repository root `LICENSE`, `NOTICE`).
- **`blur_segmentation_float.tflite`** — trained on the CUHK and DUT-DBD datasets;
  **research / non-commercial only**. See root [`MODEL_LICENSE.md`](../../MODEL_LICENSE.md).
- **Sample images** (`app/src/main/res/drawable/cc0_*`) — CC0 / public domain from
  Wikimedia Commons. See root [`CREDITS.md`](../../CREDITS.md).
