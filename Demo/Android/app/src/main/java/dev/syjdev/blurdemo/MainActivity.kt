// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.blurdemo

import android.content.res.Configuration
import android.graphics.Rect
import android.os.Bundle
import android.widget.LinearLayout
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.isVisible
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.progressindicator.CircularProgressIndicatorSpec
import com.google.android.material.progressindicator.IndeterminateDrawable
import dev.syjdev.blurdemo.DemoViewModel.Phase
import dev.syjdev.blurdemo.databinding.ActivityMainBinding
import dev.syjdev.blurdemo.databinding.TimingRowBinding
import kotlinx.coroutines.launch
import kotlin.time.Duration
import kotlin.time.DurationUnit

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val viewModel: DemoViewModel by viewModels()
    private lateinit var gallery: GalleryAdapter
    private var renderedPhase: Phase? = null

    // The system photo picker: no storage permission needed (falls back to the document picker on
    // devices without it).
    private val pickPhoto = registerForActivityResult(PickVisualMedia()) { uri ->
        uri?.let(viewModel::addPickedPhoto)
    }

    private val spinner by lazy {
        val spec = CircularProgressIndicatorSpec(this, null, 0,
            com.google.android.material.R.style.Widget_Material3_CircularProgressIndicator_ExtraSmall)
        spec.indicatorColors = intArrayOf(getColor(R.color.label_tertiary))
        IndeterminateDrawable.createCircularDrawable(this, spec)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        setUpPanels()
        setUpTimingRows()
        gallery = GalleryAdapter(
            scope = lifecycleScope,
            thumbnail = viewModel::thumbnail,
            onAddPhoto = { pickPhoto.launch(PickVisualMediaRequest(PickVisualMedia.ImageOnly)) },
            onSelect = viewModel::select,
        )
        binding.gallery.adapter = gallery
        binding.runButton.setOnClickListener {
            if (viewModel.state.value.phase == Phase.LOAD_FAILED) viewModel.loadModel() else viewModel.run()
        }

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.state.collect(::render)
            }
        }
    }

    private fun render(state: DemoViewModel.UiState) {
        gallery.submit(state.samples, state.selectedIndex)
        gallery.isEnabled = state.phase != Phase.ANALYZING
        binding.gallery.alpha = if (gallery.isEnabled) 1f else 0.5f

        val photo = state.photo
        binding.photoPanel.image.setImageBitmap(photo?.display)
        binding.photoPanel.detail.text = photo?.let { getString(R.string.pixel_size, it.width, it.height) }

        val result = state.result
        binding.blurMapPanel.image.setImageBitmap(result?.blurMap)
        binding.blurMapPanel.placeholder.isVisible = result == null
        binding.blurMapPanel.detail.text = result?.let { getString(R.string.pixel_size, it.blurMap.width, it.blurMap.height) }
        showTimings(result)

        binding.statusLabel.text = state.error
        binding.statusLabel.isVisible = state.error != null

        renderRunButton(state)
        if (renderedPhase == Phase.ANALYZING && state.phase == Phase.READY && result != null) {
            binding.root.post(::revealResult)
        }
        renderedPhase = state.phase
    }

    private fun renderRunButton(state: DemoViewModel.UiState) {
        val button = binding.runButton
        button.isEnabled = (state.phase == Phase.READY && state.photo != null) || state.phase == Phase.LOAD_FAILED
        button.text = getString(
            when (state.phase) {
                Phase.LOADING_MODEL -> R.string.loading
                Phase.READY -> R.string.run
                Phase.ANALYZING -> R.string.running
                Phase.LOAD_FAILED -> R.string.retry_loading
            },
        )
        button.icon = if (state.phase == Phase.LOADING_MODEL || state.phase == Phase.ANALYZING) spinner else null
    }

    private fun showTimings(result: DemoViewModel.Result?) {
        val timing = binding.timing
        val values = listOf(
            timing.preprocessing to result?.timings?.preprocessing,
            timing.inference to result?.timings?.inference,
            timing.postprocessing to result?.timings?.postprocessing,
            // Whatever the stages measured inside the library don't cover.
            timing.other to result?.let { (it.total - it.timings.total).coerceAtLeast(Duration.ZERO) },
            timing.total to result?.total,
        )
        for ((row, duration) in values) {
            row.value.text = duration?.let { getString(R.string.timing_value, it.toDouble(DurationUnit.MILLISECONDS)) }
                ?: getString(R.string.timing_empty)
        }
    }

    /** Scrolls the blur map and the timings into view if the screen is too short to show them. */
    private fun revealResult() {
        val scrollView = binding.scrollView
        val top = binding.panels.top + binding.blurMapPanel.root.top
        val bottom = binding.timing.root.bottom
        val rect = Rect(0, top, scrollView.width, bottom)
        val visibleHeight = scrollView.height
        val target = if (rect.height() > visibleHeight) rect.top else rect.bottom - visibleHeight
        if (target > scrollView.scrollY) scrollView.smoothScrollTo(0, target)
    }

    private fun setUpPanels() {
        binding.photoPanel.title.setText(R.string.photo)
        binding.photoPanel.image.contentDescription = getString(R.string.photo)
        binding.blurMapPanel.title.setText(R.string.blur_map)
        binding.blurMapPanel.image.contentDescription = getString(R.string.blur_map)
        binding.blurMapPanel.placeholder.setText(R.string.blur_map_placeholder)
        binding.blurMapPanel.legend.isVisible = true

        // Side by side when there is room for it (landscape, tablets), stacked otherwise.
        val configuration = resources.configuration
        val sideBySide = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE ||
            configuration.screenWidthDp >= 600
        val gap = (16 * resources.displayMetrics.density).toInt()
        binding.panels.orientation = if (sideBySide) LinearLayout.HORIZONTAL else LinearLayout.VERTICAL
        for ((index, panel) in listOf(binding.photoPanel.root, binding.blurMapPanel.root).withIndex()) {
            panel.layoutParams = if (sideBySide) {
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                    if (index > 0) marginStart = gap
                }
            } else {
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                    if (index > 0) topMargin = gap
                }
            }
        }
    }

    private fun setUpTimingRows() {
        val timing = binding.timing
        timing.preprocessing.setUp(R.string.timing_preprocessing, R.string.timing_preprocessing_detail)
        timing.inference.setUp(R.string.timing_inference, R.string.timing_inference_detail, emphasized = true)
        timing.postprocessing.setUp(R.string.timing_postprocessing, R.string.timing_postprocessing_detail)
        timing.other.setUp(R.string.timing_other, R.string.timing_other_detail)
        timing.total.setUp(R.string.timing_total, null, emphasized = true)
    }
}


private fun TimingRowBinding.setUp(name: Int, detail: Int?, emphasized: Boolean = false) {
    this.name.setText(name)
    if (detail != null) this.detail.setText(detail) else this.detail.isVisible = false
    if (emphasized) {
        this.name.setTypeface(this.name.typeface, android.graphics.Typeface.BOLD)
        value.setTypeface(value.typeface, android.graphics.Typeface.BOLD)
    }
}
