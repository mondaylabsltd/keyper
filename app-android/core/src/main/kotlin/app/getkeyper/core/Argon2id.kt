package app.getkeyper.core

import java.nio.Buffer
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.LongBuffer
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Argon2id, version 0x13 (RFC 9106).
 *
 * Lanes are filled on parallel threads, one segment at a time, as the algorithm's
 * synchronisation points allow. The memory is a caller-supplied buffer so that it
 * can live outside the Java heap, whose limit on Android is far smaller than RAM.
 * Interrupting the calling thread stops the computation at the next slice.
 */
object Argon2id {
    private const val VERSION = 0x13
    private const val TYPE = 2 // Argon2id
    private const val SLICES = 4
    private const val WORDS = 128 // 64-bit words in a 1 KiB block
    internal const val THREAD_NAME = "argon2id-lane"

    /**
     * [memory] needs at least [memoryKiB] KiB from position 0; its contents are overwritten, and
     * zeroed again before this returns or throws, since its blocks lead to the tag.
     * [progress] is called on the calling thread after each of the iterations × 4 slices.
     */
    fun hash(
        password: ByteArray,
        salt: ByteArray,
        iterations: Int,
        memoryKiB: Int,
        parallelism: Int,
        tagLength: Int,
        secret: ByteArray = ByteArray(0),
        associatedData: ByteArray = ByteArray(0),
        memory: ByteBuffer = ByteBuffer.allocateDirect(memoryKiB * 1024),
        progress: ((done: Int, total: Int) -> Unit)? = null,
    ): ByteArray {
        require(iterations >= 1) { "iterations must be at least 1" }
        require(parallelism in 1..0xFFFFFF) { "parallelism out of range" }
        require(memoryKiB >= 8 * parallelism) { "memory must be at least 8 KiB per lane" }
        require(memoryKiB < 1 shl 21) { "memory must be below 2 GiB" }
        require(memory.capacity() >= memoryKiB * 1024) { "memory buffer too small" }
        require(tagLength >= 4) { "tag must be at least 4 bytes" }
        require(salt.size >= 8) { "salt must be at least 8 bytes" }

        val h0 = Blake2b(64)
            .update(parallelism).update(tagLength).update(memoryKiB).update(iterations)
            .update(VERSION).update(TYPE)
            .update(password.size).update(password)
            .update(salt.size).update(salt)
            .update(secret.size).update(secret)
            .update(associatedData.size).update(associatedData)
            .digest()

        val m = Memory(memory, parallelism, segmentLength = memoryKiB / (SLICES * parallelism), iterations)
        val cursor = m.Cursor()
        val block = LongArray(WORDS)
        try {
            for (lane in 0 until parallelism) {
                for (i in 0..1) {
                    val bytes = hPrime(h0 + le32(i) + le32(lane), 1024)
                    for (k in 0 until WORDS) block[k] = bytes.readLongLE(8 * k)
                    Wipe.bytes(bytes)
                    cursor.write(lane, i, block)
                }
            }

            val pool = Executors.newFixedThreadPool(minOf(parallelism, Runtime.getRuntime().availableProcessors())) { task ->
                Thread(task, THREAD_NAME).apply { isDaemon = true }
            }
            try {
                for (pass in 0 until iterations) {
                    for (slice in 0 until SLICES) {
                        if (Thread.interrupted()) throw InterruptedException()
                        val segments = (0 until parallelism).map { lane -> Callable { m.fillSegment(pass, slice, lane) } }
                        pool.invokeAll(segments).forEach { it.get() } // also publishes the lanes' writes
                        progress?.invoke(pass * SLICES + slice + 1, iterations * SLICES)
                    }
                }
            } finally {
                pool.shutdownNow()
                // Segments already running keep writing into [memory], which the caller may unmap as
                // soon as we return (or throw): wait for them, however often we are interrupted.
                var interrupted = false
                while (true) {
                    try {
                        if (pool.awaitTermination(1, TimeUnit.MINUTES)) break
                    } catch (_: InterruptedException) {
                        interrupted = true
                    }
                }
                if (interrupted) Thread.currentThread().interrupt()
            }

            val last = LongArray(WORDS)
            for (lane in 0 until parallelism) {
                cursor.read(lane, m.laneLength - 1, block)
                for (k in 0 until WORDS) last[k] = last[k] xor block[k]
            }
            val bytes = ByteArray(1024) { (last[it / 8] ushr (8 * (it % 8))).toByte() }
            Wipe.longs(last)
            try {
                return hPrime(bytes, tagLength)
            } finally {
                Wipe.bytes(bytes)
            }
        } finally {
            // Every block leads to the tag; the lanes have stopped writing by now (see above).
            Wipe.longs(block)
            Wipe.bytes(h0)
            Wipe.buffer(memory, memoryKiB * 1024)
        }
    }

    /** H' from RFC 9106 section 3.3: BLAKE2b stretched to any output length. */
    private fun hPrime(input: ByteArray, length: Int): ByteArray {
        if (length <= 64) return Blake2b(length).update(length).update(input).digest()
        val out = ByteArray(length)
        val r = (length + 31) / 32 - 2
        var v = Blake2b(64).update(length).update(input).digest()
        v.copyInto(out, 0, 0, 32)
        for (i in 1 until r) {
            v = Blake2b(64).update(v).digest()
            v.copyInto(out, 32 * i, 0, 32)
        }
        Blake2b(length - 32 * r).update(v).digest().copyInto(out, 32 * r)
        return out
    }

    private class Memory(buffer: ByteBuffer, val parallelism: Int, val segmentLength: Int, val iterations: Int) {
        val laneLength = segmentLength * SLICES
        // Duplicates start out big-endian; native order makes the block copies plain memcpy.
        private val words: LongBuffer = buffer.duplicate().order(ByteOrder.nativeOrder()).asLongBuffer()

        /** Block access with a buffer position of its own: one per thread. */
        inner class Cursor {
            private val w = words.duplicate()

            fun read(lane: Int, index: Int, dst: LongArray) {
                (w as Buffer).position((lane * laneLength + index) * WORDS)
                w.get(dst)
            }

            fun write(lane: Int, index: Int, src: LongArray) {
                (w as Buffer).position((lane * laneLength + index) * WORDS)
                w.put(src)
            }
        }

        fun fillSegment(pass: Int, slice: Int, lane: Int) {
            val cursor = Cursor()
            var prev = LongArray(WORDS)
            var next = LongArray(WORDS)
            val ref = LongArray(WORDS)
            val r = LongArray(WORDS)
            val z = LongArray(WORDS)

            val dataIndependent = pass == 0 && slice < SLICES / 2
            val zero = LongArray(WORDS)
            val input = LongArray(WORDS)
            val addresses = LongArray(WORDS)
            if (dataIndependent) {
                input[0] = pass.toLong()
                input[1] = lane.toLong()
                input[2] = slice.toLong()
                input[3] = (laneLength * parallelism).toLong()
                input[4] = iterations.toLong()
                input[5] = TYPE.toLong()
            }
            fun nextAddresses() {
                input[6]++
                fillBlock(zero, input, addresses, false, r, z)
                fillBlock(zero, addresses, addresses, false, r, z)
            }

            // The first two blocks of every lane come from H0.
            val first = if (pass == 0 && slice == 0) 2 else 0
            if (dataIndependent && first != 0) nextAddresses()

            var current = slice * segmentLength + first
            cursor.read(lane, if (current == 0) laneLength - 1 else current - 1, prev)
            for (index in first until segmentLength) {
                val random = if (dataIndependent) {
                    if (index % WORDS == 0) nextAddresses()
                    addresses[index % WORDS]
                } else {
                    prev[0]
                }
                val refLane = if (pass == 0 && slice == 0) lane else ((random ushr 32) % parallelism).toInt()
                cursor.read(refLane, referenceIndex(pass, slice, index, random and 0xFFFFFFFFL, refLane == lane), ref)
                if (pass > 0) cursor.read(lane, current, next)
                fillBlock(prev, ref, next, pass > 0, r, z)
                cursor.write(lane, current, next)
                prev = next.also { next = prev }
                current++
            }
            for (a in arrayOf(prev, next, ref, r, z, input, addresses)) Wipe.longs(a)
        }

        /** Maps a 32-bit random value onto the blocks a new block may reference (RFC 9106 section 3.4.1.2). */
        private fun referenceIndex(pass: Int, slice: Int, index: Int, j1: Long, sameLane: Boolean): Int {
            val finished = if (pass == 0) slice * segmentLength else laneLength - segmentLength
            val area = when {
                sameLane -> finished + index - 1
                index == 0 -> finished - 1
                else -> finished
            }.toLong()
            val x = (j1 * j1) ushr 32
            val relative = area - 1 - ((area * x) ushr 32)
            val start = if (pass == 0 || slice == SLICES - 1) 0 else (slice + 1) * segmentLength
            return ((start + relative) % laneLength).toInt()
        }
    }

    /**
     * The compression function G: out = P(x ^ y) ^ (x ^ y), additionally XORed into
     * out's previous contents when [xorInto] (passes after the first). [r] and [z]
     * are scratch blocks; out may alias y.
     */
    private fun fillBlock(x: LongArray, y: LongArray, out: LongArray, xorInto: Boolean, r: LongArray, z: LongArray) {
        for (k in 0 until WORDS) r[k] = x[k] xor y[k]
        if (xorInto) {
            for (k in 0 until WORDS) z[k] = r[k] xor out[k]
        } else {
            r.copyInto(z)
        }
        for (i in 0 until 8) round(r) { 16 * i + it }
        for (i in 0 until 8) round(r) { 2 * i + 16 * (it / 2) + it % 2 }
        for (k in 0 until WORDS) out[k] = z[k] xor r[k]
    }

    /** The BLAKE2b round without message words, on the 16 words of [v] at positions p(0)..p(15). */
    private inline fun round(v: LongArray, p: (Int) -> Int) {
        g(v, p(0), p(4), p(8), p(12))
        g(v, p(1), p(5), p(9), p(13))
        g(v, p(2), p(6), p(10), p(14))
        g(v, p(3), p(7), p(11), p(15))
        g(v, p(0), p(5), p(10), p(15))
        g(v, p(1), p(6), p(11), p(12))
        g(v, p(2), p(7), p(8), p(13))
        g(v, p(3), p(4), p(9), p(14))
    }

    private fun g(v: LongArray, a: Int, b: Int, c: Int, d: Int) {
        var va = v[a]
        var vb = v[b]
        var vc = v[c]
        var vd = v[d]
        va = blaMka(va, vb); vd = (vd xor va).rotateRight(32)
        vc = blaMka(vc, vd); vb = (vb xor vc).rotateRight(24)
        va = blaMka(va, vb); vd = (vd xor va).rotateRight(16)
        vc = blaMka(vc, vd); vb = (vb xor vc).rotateRight(63)
        v[a] = va
        v[b] = vb
        v[c] = vc
        v[d] = vd
    }

    private fun blaMka(x: Long, y: Long) = x + y + 2 * (x and 0xFFFFFFFFL) * (y and 0xFFFFFFFFL)
}
