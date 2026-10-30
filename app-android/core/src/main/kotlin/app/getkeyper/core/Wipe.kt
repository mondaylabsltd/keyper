package app.getkeyper.core

import java.nio.Buffer
import java.nio.ByteBuffer

/**
 * The one place sensitive buffers are overwritten with zeros.
 *
 * What this does and does not guarantee (README, "What is wiped"): the zeros are written, and each
 * wipe then reads the buffer back into a volatile field, so the stores are observable and an
 * optimiser has a reason to keep them. Neither the JVM nor ART promises that, though; and ART's
 * moving garbage collector may already have copied a heap array elsewhere, where no code can reach
 * the copy. Off-heap memory ([buffer]) is never moved by the collector, but its pages go back to
 * the kernel afterwards just the same. So this is best-effort, which is why memory forensics is
 * outside the threat model.
 */
object Wipe {
    @Volatile
    private var sink = 0L

    fun bytes(a: ByteArray?) {
        if (a == null) return
        a.fill(0)
        var x = 0L
        for (b in a) x = x or b.toLong()
        sink = sink xor x
    }

    fun longs(a: LongArray?) {
        if (a == null) return
        a.fill(0)
        var x = 0L
        for (v in a) x = x or v
        sink = sink xor x
    }

    private val ZEROS = ByteArray(1 shl 16)

    /** The first [length] bytes of [memory], in 64 KiB copies, then one word read back per page. */
    fun buffer(memory: ByteBuffer, length: Int) {
        val w = memory.duplicate()
        (w as Buffer).position(0)
        var left = length
        while (left > 0) {
            val n = minOf(left, ZEROS.size)
            w.put(ZEROS, 0, n)
            left -= n
        }
        var x = 0L
        var i = 0
        while (i + 8 <= length) {
            x = x or memory.getLong(i)
            i += 4096
        }
        sink = sink xor x
    }
}
