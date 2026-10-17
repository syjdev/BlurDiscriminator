// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.blurdiscriminatorkit

import android.graphics.Bitmap

/**
 * The result of running [BlurDiscriminator.predict] on an image.
 *
 * Describes, per pixel, how blurry the analyzed image is. Pixel values range from `0` (clear) to
 * `255` (blurry), matched to the original image's aspect ratio.
 */
class BlurObservation internal constructor(
    /** A grayscale blur map sized to the original image's aspect ratio; brighter pixels are blurrier. */
    val blurMap: Bitmap,
    /** Raw per-pixel blur intensities of [blurMap], `0` (clear)..`255` (blurry), row-major. */
    val grayscaledPixels: ByteArray,
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
}
