// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.blurdemo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.annotation.DrawableRes
import androidx.exifinterface.media.ExifInterface
import dev.syjdev.pixelblurdetector.ImageOrientation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.max
import kotlin.math.min

/** An image the demo can analyze, bundled or picked from the photo library. */
data class Sample(val title: String, val source: Source) {
    sealed interface Source {
        data class Resource(@DrawableRes val id: Int) : Source
        data class Picked(val uri: Uri) : Source
    }

    companion object {
        // CC0 sample images (Wikimedia Commons, public domain). See "Sample image credits" in the repository README.
        private val bundledIds = listOf(
            R.drawable.cc0_cherry_blossom,
            R.drawable.cc0_flower_bokeh,
            R.drawable.cc0_ant_sunflower,
            R.drawable.cc0_highway_bokeh,
            R.drawable.cc0_misty_river,
            R.drawable.cc0_street_bokeh,
            R.drawable.cc0_morning_coffee,
            R.drawable.cc0_love_in_a_cup,
            R.drawable.cc0_dew_grass,
            R.drawable.cc0_panning_gulls,
            R.drawable.cc0_clover_closeup,
            R.drawable.cc0_icicles,
        )

        fun bundled(context: Context): List<Sample> = bundledIds.map { id ->
            // "cc0_cherry_blossom" → "Cherry blossom"
            val words = context.resources.getResourceEntryName(id).removePrefix("cc0_").replace('_', ' ')
            Sample(words.replaceFirstChar { it.uppercase() }, Source.Resource(id))
        }
    }
}

/**
 * A decoded sample: the stored pixels the model reads, the EXIF orientation it reads them with, and
 * an upright copy for the screen.
 */
class LoadedImage(val pixels: Bitmap, val orientation: ImageOrientation, val display: Bitmap) {
    /** The size of the image as displayed (after orientation), at full resolution. */
    val width: Int get() = if (orientation.swapsAxes) pixels.height else pixels.width
    val height: Int get() = if (orientation.swapsAxes) pixels.width else pixels.height
}

/** Decodes samples off the main thread. */
class SampleLoader(private val context: Context) {
    private val thumbnails = ConcurrentHashMap<Sample.Source, Bitmap>()

    suspend fun load(source: Sample.Source): LoadedImage = withContext(Dispatchers.IO) {
        // inScaled = false: the model must get the original pixels — the same ones the iOS demo
        // feeds it — never a copy rescaled for the screen density.
        val pixels = open(source).use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inScaled = false }) }
            ?: throw IOException("unsupported image format")
        // BitmapFactory ignores EXIF, so `pixels` are the stored (possibly sideways) pixels. The model
        // reads them rotated via `orientation`; only the on-screen copy is redrawn upright.
        val orientation = readOrientation(source)
        LoadedImage(pixels, orientation, pixels.upright(orientation, MAX_DISPLAY_SIZE))
    }

    /** A small upright copy, at least [size] pixels on its short side, cached per source. */
    suspend fun thumbnail(source: Sample.Source, size: Int): Bitmap? = withContext(Dispatchers.IO) {
        thumbnails[source]?.let { return@withContext it }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open(source).use { BitmapFactory.decodeStream(it, null, bounds) }
        val shortSide = min(bounds.outWidth, bounds.outHeight)
        var sampleSize = 1
        while (shortSide / (sampleSize * 2) >= size) sampleSize *= 2

        val options = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        val bitmap = open(source).use { BitmapFactory.decodeStream(it, null, options) } ?: return@withContext null
        bitmap.upright(readOrientation(source), Int.MAX_VALUE).also { thumbnails[source] = it }
    }

    private fun open(source: Sample.Source): InputStream = when (source) {
        is Sample.Source.Resource -> context.resources.openRawResource(source.id)
        is Sample.Source.Picked -> context.contentResolver.openInputStream(source.uri)
            ?: throw FileNotFoundException(source.uri.toString())
    }

    private fun readOrientation(source: Sample.Source): ImageOrientation = try {
        open(source).use { stream ->
            ImageOrientation.fromExif(
                ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL),
            )
        }
    } catch (e: IOException) {
        ImageOrientation.UP
    }

    private companion object {
        /** Larger bitmaps can exceed what a Canvas may draw; the model still gets full resolution. */
        const val MAX_DISPLAY_SIZE = 2048
    }
}

/**
 * A copy of the bitmap drawn the way [orientation] says it should be displayed, scaled down to at
 * most [maxSize] pixels on its long side (for display only).
 */
private fun Bitmap.upright(orientation: ImageOrientation, maxSize: Int): Bitmap {
    val scale = min(1f, maxSize.toFloat() / max(width, height))
    if (orientation == ImageOrientation.UP && scale == 1f) return this

    val matrix = Matrix()
    when (orientation) {
        ImageOrientation.UP -> Unit
        ImageOrientation.UP_MIRRORED -> matrix.setScale(-1f, 1f)
        ImageOrientation.DOWN -> matrix.setRotate(180f)
        ImageOrientation.DOWN_MIRRORED -> matrix.setScale(1f, -1f)
        ImageOrientation.LEFT_MIRRORED -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
        ImageOrientation.RIGHT -> matrix.setRotate(90f)
        ImageOrientation.RIGHT_MIRRORED -> { matrix.setRotate(-90f); matrix.postScale(-1f, 1f) }
        ImageOrientation.LEFT -> matrix.setRotate(-90f)
    }
    matrix.postScale(scale, scale)
    return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
}
