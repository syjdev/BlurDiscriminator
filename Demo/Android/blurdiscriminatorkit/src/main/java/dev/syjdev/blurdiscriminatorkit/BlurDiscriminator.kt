// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.blurdiscriminatorkit

import android.content.Context
import android.graphics.Bitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** Errors thrown by [BlurDiscriminator.predict]. */
sealed class BlurDiscriminatorException(message: String, cause: Throwable? = null) :
    Exception(message, cause) {
    /** The TensorFlow Lite model failed to load from the bundled assets. */
    class ModelLoadFailed(cause: Throwable) : BlurDiscriminatorException("failed to load model", cause)
    /** The input image could not be prepared (letterboxed) for the model. */
    class ImagePreprocessingFailed(message: String) : BlurDiscriminatorException(message)
    /** Inference failed while running the model. */
    class InferenceFailed(cause: Throwable) : BlurDiscriminatorException("inference failed", cause)
}

/**
 * A deep-learning based detector that classifies the clear and blurry regions of an image.
 *
 * Wraps a float TensorFlow Lite segmentation model (`blur_segmentation_float.tflite`, bundled in
 * this library's assets — the same float model the iOS Core ML path runs). Given a [Bitmap], it
 * produces a [BlurObservation] describing, per pixel, how blurry the input is.
 *
 * The input is letterboxed to the model's fixed input size (224×224) internally — aspect ratio is
 * preserved with black padding — and the blur map is cropped back to the original image's aspect
 * ratio. Any image size may be passed. Pass the photo's EXIF orientation and the rotation is applied
 * while sampling — there is no need to redraw the bitmap upright first.
 *
 * Inference is serialized by a [Mutex] and runs on [Dispatchers.Default], so a single instance is
 * safe to share across coroutines (mirroring the iOS `actor`).
 *
 * ```kotlin
 * val discriminator = BlurDiscriminator(context)
 * val orientation = ImageOrientation.fromExif(
 *     ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL),
 * )
 * discriminator.prepare()  // optional: load the model ahead of the first prediction
 * val observation = discriminator.predict(bitmap, orientation)
 * imageView.setImageBitmap(observation.blurMap)
 * ```
 */
class BlurDiscriminator(
    context: Context,
    private val modelAsset: String = "blur_segmentation_float.tflite",
    private val numberOfThreads: Int = 2,
) {
    private val appContext = context.applicationContext
    private val mutex = Mutex()
    private var predictor: TFLiteBlurPredictor? = null
    @Volatile private var closeRequested = false

    /**
     * Loads the model now instead of on the first [predict].
     *
     * Optional: call it early — e.g. when the screen that will run predictions appears — so the
     * first prediction doesn't also pay for loading the model. Calling it more than once, or
     * concurrently with `predict`, never loads the model twice. Mirrors `prepare()` on iOS.
     *
     * @throws BlurDiscriminatorException.ModelLoadFailed if the model could not be loaded. A failed
     *   load is not cached, so a later call may retry.
     */
    suspend fun prepare() {
        withPredictor { }
    }

    /**
     * Runs blur detection on the given image.
     *
     * The model is loaded on the first call and cached. Calls are serialized: concurrent callers
     * are suspended (not blocked) until the in-flight inference completes.
     *
     * @param input the image to analyze, as decoded (stored pixel order); letterboxed to the model
     *   input size internally.
     * @param orientation how [input] should be displayed — the photo's EXIF orientation, since
     *   `BitmapFactory` ignores it. Defaults to [ImageOrientation.UP].
     * @return a [BlurObservation] describing the blur map, in the displayed orientation (a
     *   [ImageOrientation.RIGHT] photo yields a portrait blur map).
     * @throws BlurDiscriminatorException if the model could not be loaded or inference failed.
     */
    suspend fun predict(
        input: Bitmap,
        orientation: ImageOrientation = ImageOrientation.UP,
    ): BlurObservation = withPredictor { it.predict(input, orientation) }

    /**
     * Releases the underlying interpreter. Safe to call multiple times, and while a prediction is
     * running — the interpreter is then released as soon as that prediction finishes. A later
     * [prepare] or [predict] loads the model again.
     */
    fun close() {
        closeRequested = true
        if (mutex.tryLock()) {
            try {
                releasePredictor()
            } finally {
                mutex.unlock()
            }
        }
    }

    /** Runs [block] with the loaded predictor, holding [mutex], on [Dispatchers.Default]. */
    private suspend fun <T> withPredictor(block: (TFLiteBlurPredictor) -> T): T = withContext(Dispatchers.Default) {
        mutex.withLock {
            try {
                val engine = predictor ?: TFLiteBlurPredictor(appContext, modelAsset, numberOfThreads)
                    .also { predictor = it }
                block(engine)
            } finally {
                // close() was called while the lock was held: release the interpreter now that it is idle.
                if (closeRequested) releasePredictor()
            }
        }
    }

    /** Must be called with [mutex] held. */
    private fun releasePredictor() {
        predictor?.close()
        predictor = null
        closeRequested = false
    }
}
