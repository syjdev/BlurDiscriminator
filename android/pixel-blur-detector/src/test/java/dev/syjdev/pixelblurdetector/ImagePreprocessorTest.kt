// SPDX-License-Identifier: Apache-2.0
package dev.syjdev.pixelblurdetector

import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import java.security.MessageDigest

class ImagePreprocessorTest {

    private data class Parity(val width: Int, val height: Int, val orientation: ImageOrientation, val sha256: String)

    /**
     * SHA-256 of the letterboxed RGB bytes of [parityImage] images — the same digests the iOS
     * framework pins in `ImageProcessingTests.parityDigests`. A mismatch means the two platforms
     * would feed the model different input for the same pixels. Update both files together, and
     * only on purpose.
     */
    private val parityDigests = listOf(
        Parity(37, 23, ImageOrientation.UP, "97b50d8254ba663c7c78c5e2f166f3c8f770428eb44b6135c44fd03c768d8691"),
        Parity(13, 17, ImageOrientation.UP, "c3164510f13b3fc69f00c2b831e8d829c7b83bf87c476adc5f35c3e8ef7fab52"),
        Parity(300, 7, ImageOrientation.UP, "45a351783624b81ea750604575517fda8fdb9b48bd5f2f7a9a2bba5ff8a2e8de"),
        Parity(640, 480, ImageOrientation.UP, "9370a60ba05455b35c8fcb77ce083224e40207a3ba73956a9962e99ed55700de"),
        Parity(480, 641, ImageOrientation.UP, "83eaf9f8d56f4ab82bebd59f332327b50b9127b69749eb798ea063d91f8e47de"),
        Parity(37, 23, ImageOrientation.UP_MIRRORED, "4d9520a71244439b17175e6db7e023255271ee951b828cc0c04df4cd1c621d3e"),
        Parity(37, 23, ImageOrientation.DOWN, "2620723f71cdeeddc1e75dbbcef64c6eea3a91c936741b0f1954f58b3b953a33"),
        Parity(37, 23, ImageOrientation.DOWN_MIRRORED, "5174553b7ccac96a90f3a1ac59620c77624a99320ab0ce97aacbb1fbb69392b6"),
        Parity(37, 23, ImageOrientation.LEFT_MIRRORED, "7f73281571f0033766ec6d2f28a84fff6054d55cb53afb81548c8572b2a56778"),
        Parity(37, 23, ImageOrientation.RIGHT, "3d17911245a5632cd4f5f8fed259e344b8ac078d6d0becccf0a48660f5bdd067"),
        Parity(37, 23, ImageOrientation.RIGHT_MIRRORED, "2ad50885144c0f555a65c8962eac67538e335b926b410e9517fe92678f235ed2"),
        Parity(37, 23, ImageOrientation.LEFT, "7a92bbcbfb49a18a74b089bae0c579d381e6cc3d3067f26dbb0b73e9e73e1279"),
        Parity(640, 480, ImageOrientation.RIGHT, "c32804e265c0ac500035fa672eeafd9020a3a8eb6fc9a4cfc21df289cea72eaa"),
        Parity(480, 641, ImageOrientation.LEFT, "60cad1358cabf410b7f0303ed7e321d5ddccc8735b163a75b700b821e367942b"),
    )

    @Test
    fun letterbox_matches_the_ios_framework() {
        for ((width, height, orientation, sha256) in parityDigests) {
            val rgb = ImagePreprocessor.letterboxRgb(parityImage(width, height), width, height, 224, 224, orientation)
            val digest = MessageDigest.getInstance("SHA-256").digest(rgb).joinToString("") { "%02x".format(it) }
            assertEquals(sha256, digest, "${width}x$height, $orientation")
        }
    }

    @Test
    fun orientation_rotates_the_sampled_pixels() {
        // A 2x1 image: red on the left, blue on the right.
        val red = (0xFF shl 24) or (0xFF shl 16)
        val blue = (0xFF shl 24) or 0xFF
        val pixels = intArrayOf(red, blue)
        fun topAndBottom(orientation: ImageOrientation): List<List<Int>> {
            val rgb = ImagePreprocessor.letterboxRgb(pixels, 2, 1, 224, 224, orientation)
            val bottom = 223 * 224 * 3  // last row, first column
            return listOf(rgb.slice(0..2), rgb.slice(bottom..bottom + 2)).map { px -> px.map { it.toInt() and 0xFF } }
        }

        // Displayed 90° clockwise, the left (red) end is on top; counter-clockwise, it is at the bottom.
        assertEquals(listOf(listOf(255, 0, 0), listOf(0, 0, 255)), topAndBottom(ImageOrientation.RIGHT))
        assertEquals(listOf(listOf(0, 0, 255), listOf(255, 0, 0)), topAndBottom(ImageOrientation.LEFT))
    }

    @Test
    fun letterbox_pads_with_black_and_keeps_solid_colors() {
        // 4x2 solid color → 224x112 content, the rest black.
        val color = (0xFF shl 24) or (10 shl 16) or (20 shl 8) or 30
        val rgb = ImagePreprocessor.letterboxRgb(IntArray(8) { color }, 4, 2, 224, 224)

        val firstPixel = rgb.copyOfRange(0, 3)
        val lastContentPixel = rgb.copyOfRange((111 * 224 + 223) * 3, (111 * 224 + 223) * 3 + 3)
        val firstPaddingPixel = rgb.copyOfRange(112 * 224 * 3, 112 * 224 * 3 + 3)
        assertArrayEquals(byteArrayOf(10, 20, 30), firstPixel)
        assertArrayEquals(byteArrayOf(10, 20, 30), lastContentPixel)
        assertArrayEquals(byteArrayOf(0, 0, 0), firstPaddingPixel)
    }

    @Test
    fun content_size_rounds_and_never_collapses() {
        fun size(w: Int, h: Int) = BlurMapGeometry.contentSize(w, h, 224, 224)
        assertEquals(224 to 149, size(1024, 682))  // 149.19 → 149
        assertEquals(224 to 150, size(1000, 668))  // 149.63 → 150
        assertEquals(149 to 224, size(682, 1024))
        assertEquals(224 to 224, size(500, 500))
        assertEquals(224 to 1, size(2240, 9))      // 0.9 → 1, not 0
        assertEquals(224 to 1, size(5000, 3))      // 0.13 → clamped to 1
        assertEquals(1 to 224, size(3, 5000))
    }

    /**
     * An opaque, noisy image whose bytes come from a 32-bit LCG — the same bytes as
     * `ImageProcessingTests.makeParityImage` on iOS (Int overflow wraps like Swift's `&*` / `&+`).
     */
    private fun parityImage(width: Int, height: Int): IntArray {
        var seed = 12345
        fun next(): Int {
            seed = seed * 1_103_515_245 + 12345
            return (seed ushr 16) and 0xFF
        }
        return IntArray(width * height) {
            val r = next()
            val g = next()
            val b = next()
            (0xFF shl 24) or (r shl 16) or (g shl 8) or b
        }
    }
}
