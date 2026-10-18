// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.pixelblurdetector

import android.graphics.Bitmap
import kotlin.time.Duration

/**
 * The result of running [PixelBlurDetector.predict] on an image.
 *
 * Describes, per pixel, how blurry the analyzed image is. Pixel values range from `0` (clear) to
 * `255` (blurry), matched to the original image's aspect ratio.
 */
class BlurObservation internal constructor(
    /** A grayscale blur map sized to the original image's aspect ratio; brighter pixels are blurrier. */
    val blurMap: Bitmap,
    /** Raw per-pixel blur intensities of [blurMap], `0` (clear)..`255` (blurry), row-major. */
    val grayscaledPixels: ByteArray,
    /** How long each stage of the prediction took. */
    val timings: Timings = Timings(Duration.ZERO, Duration.ZERO, Duration.ZERO),
) {
    /**
     * The fraction of pixels considered blurry.
     *
     * A pixel counts as blurry when its intensity is strictly greater than [threshold].
     *
     * @param threshold intensity cutoff in `0..255`; higher values count fewer pixels as blurry.
     * @return a value in `0f..1f` — blurry pixels divided by the total.
     */
    fun blurRatio(threshold: Int = 127): Float {
        if (grayscaledPixels.isEmpty()) return 0f
        var blurry = 0
        for (b in grayscaledPixels) {
            if ((b.toInt() and 0xFF) > threshold) blurry++
        }
        return blurry.toFloat() / grayscaledPixels.size
    }

    /**
     * Wall-clock durations of the stages of one [PixelBlurDetector.predict] call, measured on the
     * inference thread. Mirrors `BlurObservation.Timings` on iOS.
     *
     * Model loading, and the time a prediction waits for earlier ones to finish, are not included —
     * measure the `predict` call itself to get the end-to-end latency.
     */
    data class Timings(
        /** Letterboxing the input (orientation, resampling, padding) into the model's input tensor. */
        val preprocessing: Duration,
        /** The TensorFlow Lite interpreter run itself. */
        val inference: Duration,
        /** Cropping the model output back to the image's aspect ratio and building [blurMap]. */
        val postprocessing: Duration,
    ) {
        /** The sum of all stages. */
        val total: Duration get() = preprocessing + inference + postprocessing
    }
}
