// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.pixelblurdetector

import android.content.Context
import android.graphics.Bitmap
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.round
import kotlin.time.TimeSource

/**
 * TensorFlow Lite inference engine behind [PixelBlurDetector]. Kept internal so the library's public
 * surface stays limited to [PixelBlurDetector] and [BlurObservation].
 *
 * The float model takes a 224×224 float32 RGB image in `[0, 1]` and outputs a 1×224×224×1 float32
 * sigmoid map where bright = blurred (same model the iOS Core ML / ONNX path runs).
 */
internal class TFLiteBlurPredictor(
    context: Context,
    modelAsset: String,
    numberOfThreads: Int,
) {
    private val interpreter: Interpreter

    private val inputWidth: Int
    private val inputHeight: Int
    private val outputWidth: Int
    private val outputHeight: Int

    init {
        interpreter = try {
            val model = context.assets.open(modelAsset).use { it.readBytes() }
            val buffer = ByteBuffer.allocateDirect(model.size).order(ByteOrder.nativeOrder())
            buffer.put(model)
            buffer.rewind()
            Interpreter(buffer, Interpreter.Options().apply { numThreads = numberOfThreads })
        } catch (t: Throwable) {
            throw PixelBlurDetectorException.ModelLoadFailed(t)
        }

        // Read the tensor sizes from the model instead of hardcoding 224, so a reconverted model
        // with a different input size keeps working. Shapes are NHWC.
        val inShape = interpreter.getInputTensor(0).shape()   // [1, H, W, 3]
        val outShape = interpreter.getOutputTensor(0).shape() // [1, H, W, 1]
        inputHeight = inShape[1]
        inputWidth = inShape[2]
        outputHeight = outShape[1]
        outputWidth = outShape[2]
    }

    fun predict(input: Bitmap, orientation: ImageOrientation): BlurObservation {
        val start = TimeSource.Monotonic.markNow()
        val inputBuffer = ImagePreprocessor.toLetterboxedFloatRgb(input, inputWidth, inputHeight, orientation)
        val preprocessed = TimeSource.Monotonic.markNow()

        val pixelCount = outputWidth * outputHeight
        val outputBuffer = ByteBuffer
            .allocateDirect(pixelCount * Float.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())

        try {
            interpreter.run(inputBuffer, outputBuffer)
        } catch (t: Throwable) {
            throw PixelBlurDetectorException.InferenceFailed(t)
        }
        val inferred = TimeSource.Monotonic.markNow()

        // Crop the padded region back out so the blur map matches the displayed image's aspect ratio.
        val displayedWidth = if (orientation.swapsAxes) input.height else input.width
        val displayedHeight = if (orientation.swapsAxes) input.width else input.height
        val (cropWidth, cropHeight) = BlurMapGeometry.contentSize(
            displayedWidth, displayedHeight, outputWidth, outputHeight,
        )

        // Convert the float sigmoid map [0, 1] to 8-bit grayscale [0, 255] like iOS's vDSP path:
        // scale, clip, then round half to even (`round` on Float is IEEE rint). Only the cropped
        // region is converted, after one bulk copy out of the direct buffer.
        outputBuffer.rewind()
        val floats = FloatArray(pixelCount)
        outputBuffer.asFloatBuffer().get(floats)
        val pixels = ByteArray(cropWidth * cropHeight)
        for (row in 0 until cropHeight) {
            val source = row * outputWidth
            val destination = row * cropWidth
            for (column in 0 until cropWidth) {
                pixels[destination + column] = round((floats[source + column] * 255f).coerceIn(0f, 255f)).toInt().toByte()
            }
        }
        val blurMap = BlurMapRenderer.grayscale(pixels, cropWidth, cropHeight)
        val timings = BlurObservation.Timings(
            preprocessing = preprocessed - start,
            inference = inferred - preprocessed,
            postprocessing = inferred.elapsedNow(),
        )
        return BlurObservation(blurMap, pixels, timings)
    }

    fun close() {
        interpreter.close()
    }
}
