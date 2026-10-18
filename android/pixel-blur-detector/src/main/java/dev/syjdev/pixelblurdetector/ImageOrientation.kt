// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.pixelblurdetector

/**
 * How a bitmap's stored pixels should be displayed — the EXIF orientation of a photo. Mirrors
 * `CGImagePropertyOrientation` on iOS (same names, same EXIF values).
 *
 * `BitmapFactory` ignores EXIF, so a photo taken in portrait often decodes as a sideways bitmap.
 * Pass its orientation to [PixelBlurDetector.predict] and the rotation is applied while sampling —
 * the bitmap never has to be redrawn upright first.
 */
enum class ImageOrientation(val exifValue: Int) {
    /** As stored (EXIF 1, `ExifInterface.ORIENTATION_NORMAL`). */
    UP(1),
    /** Mirrored horizontally (EXIF 2, `ORIENTATION_FLIP_HORIZONTAL`). */
    UP_MIRRORED(2),
    /** Rotated 180° (EXIF 3, `ORIENTATION_ROTATE_180`). */
    DOWN(3),
    /** Mirrored vertically (EXIF 4, `ORIENTATION_FLIP_VERTICAL`). */
    DOWN_MIRRORED(4),
    /** Transposed — mirrored across the top-left/bottom-right diagonal (EXIF 5, `ORIENTATION_TRANSPOSE`). */
    LEFT_MIRRORED(5),
    /** Displayed rotated 90° clockwise (EXIF 6, `ORIENTATION_ROTATE_90`). */
    RIGHT(6),
    /** Transversed — mirrored across the top-right/bottom-left diagonal (EXIF 7, `ORIENTATION_TRANSVERSE`). */
    RIGHT_MIRRORED(7),
    /** Displayed rotated 90° counter-clockwise (EXIF 8, `ORIENTATION_ROTATE_270`). */
    LEFT(8);

    /** Whether the displayed image is the stored one transposed (rotated by ±90°). */
    val swapsAxes: Boolean
        get() = this == LEFT_MIRRORED || this == RIGHT || this == RIGHT_MIRRORED || this == LEFT

    companion object {
        /**
         * The orientation for an EXIF orientation value, e.g. from
         * `ExifInterface.getAttributeInt(TAG_ORIENTATION, ORIENTATION_NORMAL)`. Unknown or missing
         * values (0, "undefined") map to [UP].
         */
        fun fromExif(value: Int): ImageOrientation = entries.firstOrNull { it.exifValue == value } ?: UP
    }
}
