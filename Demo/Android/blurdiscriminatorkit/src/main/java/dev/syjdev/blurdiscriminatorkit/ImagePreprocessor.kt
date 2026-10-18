// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.blurdiscriminatorkit

import android.graphics.Bitmap
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/** Prepares a [Bitmap] into the float32 RGB tensor the float model expects. */
internal object ImagePreprocessor {

    /**
     * Letterboxes [src] into a [width]×[height] float32 RGB tensor in `[0, 1]`: aspect-fit into the
     * top-left corner, the rest padded with black. Reproduces the letterbox preprocessing the model
     * was trained with (no stretching, content top-left aligned); [BlurMapGeometry] later crops the
     * output back to this region. [orientation] is applied while sampling (see [letterboxRgb]).
     */
    fun toLetterboxedFloatRgb(
        src: Bitmap,
        width: Int,
        height: Int,
        orientation: ImageOrientation = ImageOrientation.UP,
    ): ByteBuffer {
        // getPixels can't read hardware bitmaps; it returns sRGB, non-premultiplied ARGB otherwise.
        val readable = if (src.config == Bitmap.Config.HARDWARE) src.copy(Bitmap.Config.ARGB_8888, false) else src
        val argb = IntArray(readable.width * readable.height)
        readable.getPixels(argb, 0, readable.width, 0, 0, readable.width, readable.height)

        val rgb = letterboxRgb(argb, readable.width, readable.height, width, height, orientation)
        val floats = FloatArray(rgb.size) { (rgb[it].toInt() and 0xFF) / 255f }
        val buffer = ByteBuffer
            .allocateDirect(rgb.size * Float.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
        // One bulk copy: a putFloat per value into a direct buffer costs several times more.
        buffer.asFloatBuffer().put(floats)
        return buffer
    }

    /**
     * Letterboxes a row-major ARGB image into [width]×[height] interleaved 8-bit RGB.
     *
     * The downscale is a hand-written **half-pixel bilinear** resampler — a line-by-line port of
     * `CGImage.makeAspectFitPadded` in the iOS framework, down to the order of the `Float`
     * operations and the rounding, so both platforms feed the model bit-identical input for the same
     * pixels. It matches the model's training resize (`tf.image.resize` / `cv2.INTER_LINEAR`);
     * Android's `Canvas` bitmap filtering does not.
     *
     * [orientation] is applied while sampling: the resampler reads the stored pixels through a
     * rotated / mirrored index mapping, so the output is the letterbox of the *displayed* image
     * without ever building an upright copy.
     *
     * Translucent pixels are premultiplied (composited over black), as iOS reads them. Opaque images
     * match iOS exactly; translucent ones can differ by the rounding of the premultiplication.
     */
    fun letterboxRgb(
        argb: IntArray,
        storedWidth: Int,
        storedHeight: Int,
        width: Int,
        height: Int,
        orientation: ImageOrientation = ImageOrientation.UP,
    ): ByteArray {
        require(storedWidth > 0 && storedHeight > 0 && width > 0 && height > 0)
        require(argb.size >= storedWidth * storedHeight)

        // Everything below works in displayed coordinates; `index` maps them back to `argb`.
        val sourceWidth = if (orientation.swapsAxes) storedHeight else storedWidth
        val sourceHeight = if (orientation.swapsAxes) storedWidth else storedHeight
        val index = IndexMapping.of(orientation, storedWidth, storedHeight)
        val (contentWidth, contentHeight) = BlurMapGeometry.contentSize(sourceWidth, sourceHeight, width, height)
        val xRatio = sourceWidth.toDouble() / contentWidth
        val yRatio = sourceHeight.toDouble() / contentHeight

        // Precompute the horizontal sample indices/weights once; they repeat for every row.
        val leftIndex = IntArray(contentWidth)
        val rightIndex = IntArray(contentWidth)
        val xWeight = FloatArray(contentWidth)
        for (dx in 0 until contentWidth) {
            val fx = max((dx + 0.5) * xRatio - 0.5, 0.0).toFloat()
            val x0 = min(fx.toInt(), sourceWidth - 1)
            leftIndex[dx] = index.column(x0)
            rightIndex[dx] = index.column(min(x0 + 1, sourceWidth - 1))
            xWeight[dx] = fx - x0.toFloat()
        }

        // Padding stays black.
        val output = ByteArray(width * height * 3)
        for (dy in 0 until contentHeight) {
            val fy = max((dy + 0.5) * yRatio - 0.5, 0.0).toFloat()
            val y0 = min(fy.toInt(), sourceHeight - 1)
            val y1 = min(y0 + 1, sourceHeight - 1)
            val wy = fy - y0.toFloat()
            val inverseWY = 1 - wy
            val row0 = index.row(y0)
            val row1 = index.row(y1)
            var destination = dy * width * 3
            for (dx in 0 until contentWidth) {
                val wx = xWeight[dx]
                val inverseWX = 1 - wx
                val p00 = argb[row0 + leftIndex[dx]]
                val p01 = argb[row0 + rightIndex[dx]]
                val p10 = argb[row1 + leftIndex[dx]]
                val p11 = argb[row1 + rightIndex[dx]]
                for (shift in RGB_SHIFTS) {
                    val top = channel(p00, shift) * inverseWX + channel(p01, shift) * wx
                    val bottom = channel(p10, shift) * inverseWX + channel(p11, shift) * wx
                    output[destination++] = roundHalfUp(top * inverseWY + bottom * wy).toByte()
                }
            }
        }
        return output
    }

    /**
     * Maps displayed `(x, y)` to an index into the stored pixels as `column(x) + row(y)`.
     *
     * Every EXIF orientation drives each stored axis by exactly one displayed axis, so the index
     * splits into an x-only and a y-only term — which lets the resampler keep its per-column lookup
     * table while reading the image rotated. Mirrors `RGBPixels.offsets(for:)` on iOS.
     */
    private class IndexMapping(val column: (Int) -> Int, val row: (Int) -> Int) {
        companion object {
            fun of(orientation: ImageOrientation, storedWidth: Int, storedHeight: Int): IndexMapping {
                val stride = storedWidth
                val lastX = storedWidth - 1
                val lastY = storedHeight - 1
                return when (orientation) {
                    ImageOrientation.UP -> IndexMapping({ it }, { it * stride })
                    ImageOrientation.UP_MIRRORED -> IndexMapping({ lastX - it }, { it * stride })
                    ImageOrientation.DOWN -> IndexMapping({ lastX - it }, { (lastY - it) * stride })
                    ImageOrientation.DOWN_MIRRORED -> IndexMapping({ it }, { (lastY - it) * stride })
                    ImageOrientation.LEFT_MIRRORED -> IndexMapping({ it * stride }, { it })
                    ImageOrientation.RIGHT -> IndexMapping({ (lastY - it) * stride }, { it })
                    ImageOrientation.RIGHT_MIRRORED -> IndexMapping({ (lastY - it) * stride }, { lastX - it })
                    ImageOrientation.LEFT -> IndexMapping({ it * stride }, { lastX - it })
                }
            }
        }
    }

    private val RGB_SHIFTS = intArrayOf(16, 8, 0)

    /** One 8-bit channel of an ARGB pixel as `Float`, premultiplied by its alpha. */
    private fun channel(pixel: Int, shift: Int): Float {
        val component = (pixel shr shift) and 0xFF
        val alpha = pixel ushr 24
        return (if (alpha == 0xFF) component else (component * alpha + 127) / 255).toFloat()
    }

    /**
     * Swift's `Float.rounded()` for the non-negative values produced here: nearest integer, ties
     * away from zero. (`kotlin.math.round` rounds ties to even, and `floor(v + 0.5f)` can be off by
     * one when the addition itself rounds.)
     */
    private fun roundHalfUp(value: Float): Int {
        val whole = floor(value)
        return (if (value - whole >= 0.5f) whole + 1 else whole).toInt()
    }
}
