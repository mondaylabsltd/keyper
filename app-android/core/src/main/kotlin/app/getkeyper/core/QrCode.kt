package app.getkeyper.core

import kotlin.math.abs
import kotlin.math.max

/**
 * QR Code encoder (ISO/IEC 18004) reduced to what Keyper needs: byte mode,
 * error correction level M, versions 1..40, and the lowest-penalty mask.
 */
class QrCode private constructor(val size: Int, private val modules: BooleanArray) {
    /** True for a dark module; [x] is the column and [y] the row. */
    operator fun get(x: Int, y: Int): Boolean = modules[y * size + x]

    companion object {
        fun encode(text: String): QrCode = encode(text.toByteArray(Charsets.UTF_8), mask = null)

        internal fun encode(data: ByteArray, mask: Int?): QrCode {
            val version = (1..40).firstOrNull { 4 + countBits(it) + 8 * data.size <= 8 * dataCodewords(it) }
                ?: throw IllegalArgumentException("${data.size} bytes do not fit in a QR code")
            val grid = Grid(version)
            grid.drawCodewords(addEcc(version, dataCodewords(version, data)))
            val chosen = mask ?: (0..7).minBy { grid.masked(it).penalty(grid.size) }
            return QrCode(grid.size, grid.masked(chosen))
        }

        private fun countBits(version: Int) = if (version <= 9) 8 else 16

        /** Mode indicator, length, payload, terminator and pad bytes. */
        private fun dataCodewords(version: Int, data: ByteArray): ByteArray {
            val out = ByteArray(dataCodewords(version))
            var bit = 0
            fun put(value: Int, n: Int) {
                for (i in n - 1 downTo 0) {
                    if ((value ushr i) and 1 != 0) out[bit / 8] = (out[bit / 8].toInt() or (0x80 ushr (bit % 8))).toByte()
                    bit++
                }
            }
            put(0b0100, 4)
            put(data.size, countBits(version))
            for (b in data) put(b.toInt() and 0xFF, 8)
            // Up to four terminator bits and the padding to a byte boundary are already zero.
            var pad = 0xEC
            for (i in (minOf(bit + 4, 8 * out.size) + 7) / 8 until out.size) {
                out[i] = pad.toByte()
                pad = pad xor (0xEC xor 0x11)
            }
            return out
        }

        /** Splits data into blocks, appends Reed-Solomon codewords to each, and interleaves them. */
        private fun addEcc(version: Int, data: ByteArray): ByteArray {
            val blocks = BLOCKS[version]
            val eccLength = ECC_PER_BLOCK[version]
            val raw = rawDataModules(version) / 8
            val shortBlocks = blocks - raw % blocks
            val shortLength = raw / blocks // including ECC
            val divisor = rsDivisor(eccLength)
            var k = 0
            val split = List(blocks) { i ->
                val dataLength = shortLength - eccLength + if (i < shortBlocks) 0 else 1
                val d = data.copyOfRange(k, k + dataLength).also { k += dataLength }
                d to rsRemainder(d, divisor)
            }
            val out = ByteArray(raw)
            var n = 0
            for (i in 0..shortLength - eccLength) for ((d, _) in split) if (i < d.size) out[n++] = d[i]
            for (i in 0 until eccLength) for ((_, e) in split) out[n++] = e[i]
            return out
        }

        private fun rsDivisor(degree: Int): ByteArray {
            val r = ByteArray(degree).also { it[degree - 1] = 1 }
            var root = 1
            repeat(degree) {
                for (j in r.indices) {
                    r[j] = gfMul(r[j].toInt() and 0xFF, root).toByte()
                    if (j + 1 < r.size) r[j] = (r[j].toInt() xor r[j + 1].toInt()).toByte()
                }
                root = gfMul(root, 2)
            }
            return r
        }

        private fun rsRemainder(data: ByteArray, divisor: ByteArray): ByteArray {
            val r = ByteArray(divisor.size)
            for (b in data) {
                val factor = (b.toInt() xor r[0].toInt()) and 0xFF
                r.copyInto(r, 0, 1)
                r[r.size - 1] = 0
                for (i in r.indices) r[i] = (r[i].toInt() xor gfMul(divisor[i].toInt() and 0xFF, factor)).toByte()
            }
            return r
        }

        /** Multiplication in GF(2^8) modulo x^8 + x^4 + x^3 + x^2 + 1. */
        private fun gfMul(x: Int, y: Int): Int {
            var z = 0
            for (i in 7 downTo 0) {
                z = (z shl 1) xor ((z ushr 7) * 0x11D)
                z = z xor ((y ushr i) and 1) * x
            }
            return z
        }

        private fun rawDataModules(version: Int): Int {
            var r = (16 * version + 128) * version + 64
            if (version >= 2) {
                val align = version / 7 + 2
                r -= (25 * align - 10) * align - 55
                if (version >= 7) r -= 36
            }
            return r
        }

        private fun dataCodewords(version: Int) = rawDataModules(version) / 8 - ECC_PER_BLOCK[version] * BLOCKS[version]

        // Error correction level M, indexed by version (index 0 unused).
        private val ECC_PER_BLOCK = intArrayOf(
            0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
            26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
        )
        private val BLOCKS = intArrayOf(
            0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
            17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49,
        )
    }

    /** The symbol before masking: function patterns plus the placed codewords. */
    private class Grid(val version: Int) {
        val size = 4 * version + 17
        private val dark = BooleanArray(size * size)
        private val function = BooleanArray(size * size)

        init {
            for (i in 0 until size) {
                set(6, i, i % 2 == 0)
                set(i, 6, i % 2 == 0)
            }
            finder(3, 3)
            finder(size - 4, 3)
            finder(3, size - 4)
            val align = alignmentPositions()
            val last = align.lastIndex
            for (i in align.indices) for (j in align.indices) {
                if (i == 0 && j == 0 || i == 0 && j == last || i == last && j == 0) continue
                for (dy in -2..2) for (dx in -2..2) set(align[i] + dx, align[j] + dy, max(abs(dx), abs(dy)) != 1)
            }
            drawFormat(dark, 0) // reserves the format area; the real bits depend on the mask
            if (version >= 7) {
                var rem = version
                repeat(12) { rem = (rem shl 1) xor ((rem ushr 11) * 0x1F25) }
                val bits = version shl 12 or rem
                for (i in 0 until 18) {
                    val bit = (bits ushr i) and 1 != 0
                    set(size - 11 + i % 3, i / 3, bit)
                    set(i / 3, size - 11 + i % 3, bit)
                }
            }
        }

        private fun set(x: Int, y: Int, isDark: Boolean) {
            dark[y * size + x] = isDark
            function[y * size + x] = true
        }

        private fun finder(cx: Int, cy: Int) {
            for (dy in -4..4) for (dx in -4..4) {
                val x = cx + dx
                val y = cy + dy
                if (x in 0 until size && y in 0 until size) {
                    val d = max(abs(dx), abs(dy))
                    set(x, y, d != 2 && d != 4)
                }
            }
        }

        private fun alignmentPositions(): IntArray {
            if (version == 1) return IntArray(0)
            val n = version / 7 + 2
            val step = (version * 8 + n * 3 + 5) / (n * 4 - 4) * 2
            return IntArray(n) { if (it == 0) 6 else size - 7 - (n - 1 - it) * step }
        }

        /** Places codeword bits in the two-column zigzag, skipping function modules. */
        fun drawCodewords(codewords: ByteArray) {
            var i = 0
            var right = size - 1
            while (right >= 1) {
                if (right == 6) right = 5 // skip the vertical timing pattern
                val upward = (right + 1) and 2 == 0
                for (vert in 0 until size) {
                    val y = if (upward) size - 1 - vert else vert
                    for (x in right downTo right - 1) {
                        if (!function[y * size + x] && i < codewords.size * 8) {
                            dark[y * size + x] = (codewords[i / 8].toInt() ushr (7 - i % 8)) and 1 != 0
                            i++
                        }
                    }
                }
                right -= 2
            }
        }

        fun masked(mask: Int): BooleanArray {
            val out = dark.copyOf()
            for (y in 0 until size) for (x in 0 until size) {
                if (!function[y * size + x] && maskBit(mask, x, y)) out[y * size + x] = !out[y * size + x]
            }
            drawFormat(out, mask)
            return out
        }

        /** Writes both copies of the 15 format bits (level M = 00, then the mask) and the dark module. */
        private fun drawFormat(m: BooleanArray, mask: Int) {
            var rem = mask
            repeat(10) { rem = (rem shl 1) xor ((rem ushr 9) * 0x537) }
            val bits = (mask shl 10 or rem) xor 0x5412
            fun put(x: Int, y: Int, i: Int) {
                m[y * size + x] = (bits ushr i) and 1 != 0
                function[y * size + x] = true
            }
            for (i in 0..5) put(8, i, i)
            put(8, 7, 6)
            put(8, 8, 7)
            put(7, 8, 8)
            for (i in 9 until 15) put(14 - i, 8, i)
            for (i in 0 until 8) put(size - 1 - i, 8, i)
            for (i in 8 until 15) put(8, size - 15 + i, i)
            m[(size - 8) * size + 8] = true
            function[(size - 8) * size + 8] = true
        }

        private fun maskBit(mask: Int, x: Int, y: Int) = when (mask) {
            0 -> (x + y) % 2 == 0
            1 -> y % 2 == 0
            2 -> x % 3 == 0
            3 -> (x + y) % 3 == 0
            4 -> (x / 3 + y / 2) % 2 == 0
            5 -> x * y % 2 + x * y % 3 == 0
            6 -> (x * y % 2 + x * y % 3) % 2 == 0
            else -> ((x + y) % 2 + x * y % 3) % 2 == 0
        }
    }
}

/** The standard mask penalty: long runs, 2x2 blocks, finder-like patterns, and dark/light imbalance. */
private fun BooleanArray.penalty(size: Int): Int {
    var score = 0
    for (horizontal in listOf(true, false)) {
        for (a in 0 until size) {
            val history = IntArray(7)
            var color = false
            var run = 0
            fun push(length: Int) {
                val withBorder = if (history[0] == 0) length + size else length // light border before the first run
                history.copyInto(history, 1, 0, 6)
                history[0] = withBorder
            }
            for (b in 0 until size) {
                val c = if (horizontal) this[a * size + b] else this[b * size + a]
                if (c == color) {
                    run++
                    if (run == 5) score += 3 else if (run > 5) score++
                } else {
                    push(run)
                    if (!color) score += 40 * finderLike(history)
                    color = c
                    run = 1
                }
            }
            if (color) {
                push(run)
                run = 0
            }
            push(run + size) // light border after the last run
            score += 40 * finderLike(history)
        }
    }
    for (y in 0 until size - 1) for (x in 0 until size - 1) {
        val c = this[y * size + x]
        if (c == this[y * size + x + 1] && c == this[(y + 1) * size + x] && c == this[(y + 1) * size + x + 1]) score += 3
    }
    val dark = count { it }
    val total = size * size
    score += 10 * ((abs(dark * 20 - total * 10) + total - 1) / total - 1)
    return score
}

/** Counts 1:1:3:1:1 dark-light patterns with four light modules on either side. */
private fun finderLike(h: IntArray): Int {
    val n = h[1]
    val core = n > 0 && h[2] == n && h[3] == n * 3 && h[4] == n && h[5] == n
    return (if (core && h[0] >= n * 4 && h[6] >= n) 1 else 0) + (if (core && h[6] >= n * 4 && h[0] >= n) 1 else 0)
}
