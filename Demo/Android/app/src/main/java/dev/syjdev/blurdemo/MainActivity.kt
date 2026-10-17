// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.blurdemo

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Bundle
import android.os.SystemClock
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import dev.syjdev.blurdemo.databinding.ActivityMainBinding
import dev.syjdev.blurdiscriminatorkit.BlurDiscriminator
import dev.syjdev.blurdiscriminatorkit.ImageOrientation
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var blurDiscriminator: BlurDiscriminator

    // CC0 sample images (Wikimedia Commons, public domain). See Demo/Android CREDITS.
    private val imageResIds = listOf(
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
    private var currentImageIndex = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        blurDiscriminator = BlurDiscriminator(this)
        binding.runButton.setOnClickListener { runBlurDetection() }
    }

    private fun runBlurDetection() {
        val resId = imageResIds[currentImageIndex]
        currentImageIndex = (currentImageIndex + 1) % imageResIds.size

        // inScaled = false: `res/drawable` is the mdpi baseline, so by default Android would upscale
        // the photo by the screen density (with its own filter) before the model ever sees it. The
        // model must get the original pixels — the same ones the iOS demo feeds it.
        val inputBitmap = BitmapFactory.decodeResource(
            resources,
            resId,
            BitmapFactory.Options().apply { inScaled = false },
        )
        // BitmapFactory ignores EXIF, so `inputBitmap` holds the stored (possibly sideways) pixels.
        // The model reads them rotated via `orientation`; only the on-screen copy is redrawn upright.
        val orientation = readOrientation(resId)
        binding.inputImage.setImageBitmap(inputBitmap.upright(orientation))
        binding.outputImage.setImageDrawable(null)
        binding.statusLabel.text = getString(R.string.idle)

        val startedAt = SystemClock.elapsedRealtime()
        lifecycleScope.launch {
            runCatching { blurDiscriminator.predict(inputBitmap, orientation) }
                .onSuccess { observation ->
                    val elapsedMs = SystemClock.elapsedRealtime() - startedAt
                    binding.outputImage.setImageBitmap(observation.blurMap)
                    binding.statusLabel.text = getString(
                        R.string.result_format,
                        elapsedMs,
                        observation.blurRatio(),
                    )
                }
                .onFailure { error ->
                    binding.statusLabel.text = getString(R.string.error_format, error.message ?: "unknown")
                }
        }
    }

    private fun readOrientation(resId: Int): ImageOrientation =
        resources.openRawResource(resId).use { stream ->
            ImageOrientation.fromExif(
                ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL),
            )
        }

    override fun onDestroy() {
        blurDiscriminator.close()
        super.onDestroy()
    }
}


/** A copy of the bitmap drawn the way [orientation] says it should be displayed (for display only). */
private fun Bitmap.upright(orientation: ImageOrientation): Bitmap {
    val matrix = Matrix()
    when (orientation) {
        ImageOrientation.UP -> return this
        ImageOrientation.UP_MIRRORED -> matrix.setScale(-1f, 1f)
        ImageOrientation.DOWN -> matrix.setRotate(180f)
        ImageOrientation.DOWN_MIRRORED -> matrix.setScale(1f, -1f)
        ImageOrientation.LEFT_MIRRORED -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
        ImageOrientation.RIGHT -> matrix.setRotate(90f)
        ImageOrientation.RIGHT_MIRRORED -> { matrix.setRotate(-90f); matrix.postScale(-1f, 1f) }
        ImageOrientation.LEFT -> matrix.setRotate(-90f)
    }
    return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
}
