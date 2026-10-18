# BlurDiscriminator

**On-device, pixel-level blur detection for iOS (Core ML) and Android (TensorFlow Lite).**

BlurDiscriminator tells you *where* an image is blurry. Its output is a blur map with one value
per pixel, not a single score, so you can see which parts of a photo are in focus. It runs on the
device with a small segmentation model, and the same model produces matching results on both
platforms.

<p>
  <img src="https://img.shields.io/badge/iOS-16.2+-0099FF?style=flat&logo=apple" />
  <img src="https://img.shields.io/badge/Android-API%2026+-3DDC84?style=flat&logo=android&logoColor=white" />
  <img src="https://img.shields.io/badge/Core%20ML-✓-BF53FF?style=flat" />
  <img src="https://img.shields.io/badge/TensorFlow%20Lite-✓-FF6F00?style=flat" />
  <img src="https://img.shields.io/badge/code-Apache--2.0-blue?style=flat" />
  <img src="https://img.shields.io/badge/model-non--commercial-lightgrey?style=flat" />
</p>

<div align="center">
  <img src="docs/images/hero.jpg" width="100%" alt="Input photos (top) and their blur maps (bottom)" />
  <br />
  <sub><b>Top:</b> input · <b>Bottom:</b> blur map (white = blurry, black = sharp) · CC0 photos, see <a href="#sample-image-credits">credits</a></sub>
</div>

## Features

- **Per-pixel blur map**: separates the sharp subject from defocused or motion-blurred regions,
  rather than returning one score for the whole image.
- **Simple blur check**: `blurRatio()` gives the fraction of blurry pixels, which you can
  threshold to decide whether a photo is blurry.
- **Runs entirely on device**: there is no server or network call. On iOS it uses the CPU, GPU or
  Neural Engine through Core ML; on Android it uses TensorFlow Lite.
- **Same results on iOS and Android**: both platforms run the same float model with the same
  preprocessing code (letterbox and bilinear resample), so a given image produces the same model
  input on each.
- **Any image size**: input is letterboxed to 224×224, and the map is cropped back to the image's
  aspect ratio and EXIF orientation.
- **Built-in profiling**: every result reports how long preprocessing, inference and
  postprocessing took.

## Use cases

- Rejecting blurry shots right after capture, in a camera, document scanner or ID verification flow
- Culling blurry photos in a gallery or photo-backup app
- Finding the subject of a photo with a shallow depth of field, for cropping, refocusing effects or
  portrait-mode checks

## Quick start

### iOS (Swift)

```swift
import BlurDiscriminatorKit

let discriminator = BlurDiscriminator()          // an actor; share one instance
try await discriminator.prepare()                // optional: preload the model

let observation = try await discriminator.predict(input: cgImage, orientation: .up)

imageView.image = UIImage(cgImage: observation.blurMap)  // brighter = blurrier
let isBlurry = observation.blurRatio() > 0.5
```

See [`Demo/iOS`](Demo/iOS) to add the framework to your app or to run the demo.

### Android (Kotlin)

```kotlin
import dev.syjdev.blurdiscriminatorkit.BlurDiscriminator
import dev.syjdev.blurdiscriminatorkit.ImageOrientation

val discriminator = BlurDiscriminator(context)   // share one instance
discriminator.prepare()                          // optional: preload the model

val observation = discriminator.predict(bitmap, ImageOrientation.fromExif(exifOrientation))

imageView.setImageBitmap(observation.blurMap)    // brighter = blurrier
val isBlurry = observation.blurRatio() > 0.5f
```

See [`Demo/Android`](Demo/Android) for the library module and the demo app.

> Swift Package Manager and Maven/JitPack distribution are planned. For now, add the framework
> or module from this repository as described in each platform's README.

## How it works

```
image ──► letterbox to 224×224 ──► segmentation model ──► 224×224 sigmoid map ──► crop back to
(any size,  (aspect fit, black      (Core ML / TFLite)                            aspect ratio,
 EXIF-aware) padding, RGB [0,1])                                                  0–255 grayscale
```

The model was trained with letterbox preprocessing, so both SDKs letterbox the same way. The
bilinear resampler on Android is a line-by-line port of the iOS one; it does not use `Canvas`
filtering. See [`Demo/Android/README.md`](Demo/Android/README.md#preprocessing-parity-with-ios)
for details.

## Models

| File | Format | Size | Used by |
|---|---|---|---|
| `Demo/iOS/BlurDiscriminatorKit/BlurDiscriminatorKit/BlurSegmentation.mlpackage` | Core ML, float | 2.1 MB | iOS SDK |
| `Demo/Android/blurdiscriminatorkit/src/main/assets/blur_segmentation_float.tflite` | TFLite, float32 | 4.0 MB | Android SDK |

Input: `1×224×224×3` float32 RGB in `[0, 1]`. Output: `1×224×224×1` float32 sigmoid, where 1 is
blurry.

## Repository layout

```
Demo/
├── iOS/       BlurDiscriminatorKit (framework + tests) and the demo app — open iOS.xcworkspace
└── Android/   blurdiscriminatorkit (AAR library + tests) and the demo app — open in Android Studio
```

## Training data

The model was trained on two research datasets:

- [CUHK Blur Detection Dataset](http://www.cse.cuhk.edu.hk/~leojia/projects/dblurdetect/dataset.html): J. Shi, L. Xu, J. Jia, *Discriminative Blur Detection Features*, CVPR 2014
- [DUT-DBD](https://openaccess.thecvf.com/content_cvpr_2018/html/Zhao_Defocus_Blur_Detection_CVPR_2018_paper.html): W. Zhao, F. Zhao, D. Wang, H. Lu, *Defocus Blur Detection via Multi-stream Bottom-Top-Bottom Fully Convolutional Network*, CVPR 2018

## License

| What | License |
|---|---|
| Source code (SDKs and demo apps) | **Apache-2.0**. Commercial use is allowed; keep [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE) when redistributing. |
| Demo and test images (`cc0_*`) | **CC0** (public domain) from Wikimedia Commons, with no restrictions. See [credits](#sample-image-credits). |
| Bundled models (`.mlpackage`, `.tflite`) | **Unclear; non-commercial for now.** See below. |

The models were trained on the CUHK Blur Detection and DUT-DBD datasets. Neither dataset states a
license, so we can't confirm that commercial use is allowed. Until that's resolved, the models are
offered for research and non-commercial use only. If you want to use them commercially, contact the
dataset authors first. Details are in [`MODEL_LICENSE.md`](MODEL_LICENSE.md).

### Sample image credits

The sample images in the demo apps and tests (`cc0_*`) are CC0 photos from Wikimedia Commons,
downscaled to 1024 px on the longest side. CC0 needs no attribution; the sources are listed so you
can check where each image came from.

<details>
<summary>Sources (12 images)</summary>

| File | Source (Wikimedia Commons) |
|---|---|
| `cc0_cherry_blossom` | [Brightin Star 35mm f0.95 - Cherry Blossom](https://commons.wikimedia.org/wiki/File:Brightin_Star_35mm_f0.95_-_Cherry_Blossom.jpg) |
| `cc0_flower_bokeh` | [Beautiful Flower covered in an artistic Bokeh](https://commons.wikimedia.org/wiki/File:Beautiful_Flower_covered_in_an_artistic_Bokeh_(54028221085).jpg) |
| `cc0_ant_sunflower` | [Ant on sunflower with snail](https://commons.wikimedia.org/wiki/File:Ant_on_sunflower_with_snail.jpg) |
| `cc0_highway_bokeh` | [Highway Bokeh](https://commons.wikimedia.org/wiki/File:Highway_Bokeh_(49256321736).jpg) |
| `cc0_misty_river` | [Blurry misty river](https://commons.wikimedia.org/wiki/File:Blurry_misty_river.jpg) |
| `cc0_street_bokeh` | [Street bokeh (Unsplash)](https://commons.wikimedia.org/wiki/File:Street_bokeh_(Unsplash).jpg) |
| `cc0_morning_coffee` | [Morning coffee (Unsplash)](https://commons.wikimedia.org/wiki/File:Morning_coffee_(Unsplash).jpg) |
| `cc0_love_in_a_cup` | [Love in a cup (Unsplash)](https://commons.wikimedia.org/wiki/File:Love_in_a_cup_(Unsplash).jpg) |
| `cc0_dew_grass` | [Dew on Grass, beautiful greenery](https://commons.wikimedia.org/wiki/File:Dew_on_Grass,_beautiful_greenery.jpg) |
| `cc0_panning_gulls` | [Panning gulls](https://commons.wikimedia.org/wiki/File:Panning_gulls.jpg) |
| `cc0_clover_closeup` | [Trifolium subterraneum close-up](https://commons.wikimedia.org/wiki/File:Trifolium_subterraneum_close-up.jpg) |
| `cc0_icicles` | [Icicles on a winter morning](https://commons.wikimedia.org/wiki/File:Icicles_on_a_winter_morning_(30982282464).jpg) |

</details>

## Contributing

Issues and pull requests are welcome, including bug reports, results on new devices, and
comparisons with other blur-detection methods.
