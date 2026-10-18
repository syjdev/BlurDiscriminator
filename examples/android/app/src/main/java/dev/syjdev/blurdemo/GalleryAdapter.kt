// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.blurdemo

import android.graphics.Bitmap
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isVisible
import androidx.recyclerview.widget.RecyclerView
import dev.syjdev.blurdemo.databinding.ItemThumbnailBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** The horizontal image picker: an "add photo" cell, then the samples. */
class GalleryAdapter(
    private val scope: CoroutineScope,
    private val thumbnail: suspend (Sample, Int) -> Bitmap?,
    private val onAddPhoto: () -> Unit,
    private val onSelect: (Int) -> Unit,
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    private var samples: List<Sample> = emptyList()
    private var selectedIndex = -1

    /** Locked while a prediction runs. */
    var isEnabled = true

    fun submit(samples: List<Sample>, selectedIndex: Int) {
        if (samples != this.samples) {
            this.samples = samples
            this.selectedIndex = selectedIndex
            notifyDataSetChanged()
        } else if (selectedIndex != this.selectedIndex) {
            val previous = this.selectedIndex
            this.selectedIndex = selectedIndex
            notifyItemChanged(previous + 1, SELECTION)
            notifyItemChanged(selectedIndex + 1, SELECTION)
        }
    }

    override fun getItemCount() = samples.size + 1

    override fun getItemViewType(position: Int) = if (position == 0) ADD_PHOTO else THUMBNAIL

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)
        return if (viewType == ADD_PHOTO) {
            val view = inflater.inflate(R.layout.item_add_photo, parent, false)
            view.setOnClickListener { if (isEnabled) onAddPhoto() }
            object : RecyclerView.ViewHolder(view) {}
        } else {
            ThumbnailHolder(ItemThumbnailBinding.inflate(inflater, parent, false))
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int, payloads: List<Any>) {
        if (holder is ThumbnailHolder && payloads.isNotEmpty()) {
            holder.showSelection(position - 1 == selectedIndex)
        } else {
            onBindViewHolder(holder, position)
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        if (holder is ThumbnailHolder) holder.bind(samples[position - 1], position - 1 == selectedIndex)
    }

    inner class ThumbnailHolder(private val binding: ItemThumbnailBinding) : RecyclerView.ViewHolder(binding.root) {
        private var thumbnailJob: Job? = null

        init {
            binding.root.setOnClickListener {
                val index = bindingAdapterPosition - 1
                if (isEnabled && index >= 0) onSelect(index)
            }
        }

        fun bind(sample: Sample, selected: Boolean) {
            binding.root.contentDescription = sample.title
            showSelection(selected)
            // Decode a small thumbnail off the main thread instead of scaling the full photo on screen.
            thumbnailJob?.cancel()
            binding.image.setImageBitmap(null)
            val size = binding.root.layoutParams.width * 3 / 2
            thumbnailJob = scope.launch { binding.image.setImageBitmap(thumbnail(sample, size)) }
        }

        fun showSelection(selected: Boolean) {
            binding.selection.isVisible = selected
            binding.root.isSelected = selected
        }
    }

    private companion object {
        const val ADD_PHOTO = 0
        const val THUMBNAIL = 1
        val SELECTION = Any()
    }
}
