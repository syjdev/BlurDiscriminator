// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.pixelblurdetector

import android.graphics.Bitmap
import kotlin.math.floor
import kotlin.math.min

/**
 * Maps the square model output back onto the original image's aspect ratio, mirroring the top-left
 * letterbox placement used by [ImagePreprocessor.letterboxRgb].
 */
internal object BlurMapGeometry {
    /**
     * Size of an image's content inside a [canvasWidth]×[canvasHeight] letterbox: aspect-fit,
     * rounded to whole pixels, and never empty.
     *
     * [ImagePreprocessor.letterboxRgb] draws the content at this size and the blur map is cropped back
     * out of the model output with it, so the two always agree on which pixels are image content —
     * even for extreme aspect ratios, where the short side is a single pixel. Mirrors
     * `BlurMapGeometry.contentSize` on iOS.
     */
    fun contentSize(
        sourceWidth: Int,
        sourceHeight: Int,
        canvasWidth: Int,
        canvasHeight: Int,
    ): Pair<Int, Int> {
        if (sourceWidth <= 0 || sourceHeight <= 0) return canvasWidth to canvasHeight
        val scale = min(canvasWidth.toDouble() / sourceWidth, canvasHeight.toDouble() / sourceHeight)
        // floor(x + 0.5) rounds ties up like Swift's `rounded()` does for positive values
        // (kotlin.math.round would round ties to even).
        val width = floor(sourceWidth * scale + 0.5).toInt().coerceIn(1, canvasWidth)
        val height = floor(sourceHeight * scale + 0.5).toInt().coerceIn(1, canvasHeight)
        return width to height
    }
}

/** Builds an 8-bit grayscale [Bitmap] from the model's per-pixel intensities. */
internal object BlurMapRenderer {
    fun grayscale(pixels: ByteArray, width: Int, height: Int): Bitmap {
        val argb = IntArray(width * height)
        for (i in 0 until width * height) {
            val v = pixels[i].toInt() and 0xFF
            argb[i] = (0xFF shl 24) or (v shl 16) or (v shl 8) or v
        }
        return Bitmap.createBitmap(argb, width, height, Bitmap.Config.ARGB_8888)
    }
}
