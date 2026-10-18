// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.blurdemo

import android.app.Application
import android.graphics.Bitmap
import android.net.Uri
import androidx.annotation.StringRes
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.syjdev.pixelblurdetector.BlurObservation
import dev.syjdev.pixelblurdetector.PixelBlurDetector
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.time.Duration
import kotlin.time.TimeSource

/**
 * The demo's state. Lives across configuration changes, so rotating the device or switching to dark
 * mode keeps the selection and result, and never reloads the model.
 */
class DemoViewModel(application: Application) : AndroidViewModel(application) {
    enum class Phase { LOADING_MODEL, READY, ANALYZING, LOAD_FAILED }

    class Result(val blurMap: Bitmap, val timings: BlurObservation.Timings, val total: Duration)

    data class UiState(
        val phase: Phase = Phase.LOADING_MODEL,
        val samples: List<Sample> = emptyList(),
        val selectedIndex: Int = 0,
        /** The selected sample, once decoded. */
        val photo: LoadedImage? = null,
        /** The blur map of [photo]; cleared whenever the selection changes. */
        val result: Result? = null,
        val error: String? = null,
    )

    private val blurDetector = PixelBlurDetector(application)
    private val loader = SampleLoader(application)
    private val _state = MutableStateFlow(UiState(samples = Sample.bundled(application)))
    val state: StateFlow<UiState> = _state.asStateFlow()
    private var photoJob: Job? = null

    init {
        loadModel()
        select(0)
    }

    fun loadModel() {
        _state.update { it.copy(phase = Phase.LOADING_MODEL, error = null) }
        viewModelScope.launch {
            try {
                blurDetector.prepare()
                // The interpreter's first run pays for one-time setup. Spend it on a blank image here,
                // so the first measured Run is as fast as the ones after it.
                blurDetector.predict(Bitmap.createBitmap(224, 224, Bitmap.Config.ARGB_8888))
                _state.update { it.copy(phase = Phase.READY) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(phase = Phase.LOAD_FAILED, error = string(R.string.error_model, e.describe())) }
            }
        }
    }

    fun run() {
        val current = _state.value
        val photo = current.photo ?: return
        if (current.phase != Phase.READY) return

        // One prediction at a time, and the gallery is locked meanwhile, so the result always
        // belongs to the photo on screen.
        _state.update { it.copy(phase = Phase.ANALYZING, error = null) }
        viewModelScope.launch {
            val start = TimeSource.Monotonic.markNow()
            try {
                val observation = blurDetector.predict(photo.pixels, photo.orientation)
                val result = Result(observation.blurMap, observation.timings, start.elapsedNow())
                _state.update { it.copy(phase = Phase.READY, result = result) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(phase = Phase.READY, error = string(R.string.error_prediction, e.describe())) }
            }
        }
    }

    fun select(index: Int) {
        val current = _state.value
        if (current.phase == Phase.ANALYZING || index !in current.samples.indices) return

        // Clear the previous result so a photo is never shown next to another photo's blur map.
        _state.update { it.copy(selectedIndex = index, photo = null, result = null, error = null) }
        val source = current.samples[index].source
        photoJob?.cancel()
        photoJob = viewModelScope.launch {
            try {
                val photo = loader.load(source)
                _state.update { it.copy(photo = photo) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(error = string(R.string.error_photo, e.describe())) }
            }
        }
    }

    fun addPickedPhoto(uri: Uri) {
        val sample = Sample(string(R.string.your_photo), Sample.Source.Picked(uri))
        _state.update { it.copy(samples = listOf(sample) + it.samples) }
        select(0)
    }

    suspend fun thumbnail(sample: Sample, size: Int): Bitmap? = loader.thumbnail(sample.source, size)

    override fun onCleared() {
        blurDetector.close()
    }

    private fun string(@StringRes id: Int, vararg args: Any): String = getApplication<Application>().getString(id, *args)

    private fun Throwable.describe(): String =
        generateSequence(this) { it.cause }.mapNotNull { it.message }.distinct().joinToString(": ").ifEmpty { toString() }
}
