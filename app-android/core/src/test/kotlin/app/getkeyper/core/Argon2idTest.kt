package app.getkeyper.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicReference

class Argon2idTest {
    @Test
    fun blake2b() {
        assertEquals(
            "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419" +
                "d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce",
            Blake2b(64).digest().hex(),
        )
        assertEquals(
            "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1" +
                "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923",
            Blake2b(64).update("abc".toByteArray()).digest().hex(),
        )
        // Feeding in pieces across the 128-byte block boundary must not matter.
        val data = ByteArray(300) { it.toByte() }
        assertEquals(
            Blake2b(32).update(data).digest().hex(),
            Blake2b(32).update(data.copyOfRange(0, 128)).update(data.copyOfRange(128, 129)).update(data.copyOfRange(129, 300)).digest().hex(),
        )
    }

    /** RFC 9106 section 5.3, which also covers the secret and associated-data inputs. */
    @Test
    fun rfc9106() {
        val tag = Argon2id.hash(
            password = ByteArray(32) { 1 },
            salt = ByteArray(16) { 2 },
            iterations = 3,
            memoryKiB = 32,
            parallelism = 4,
            tagLength = 32,
            secret = ByteArray(8) { 3 },
            associatedData = ByteArray(12) { 4 },
        )
        assertEquals("0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659", tag.hex())
    }

    /** The working memory leads to the tag: it must be all zeros again once hash() is done. */
    @Test
    fun workingMemoryIsZeroedAfterwards() {
        val memory = ByteBuffer.allocateDirect(32 * 1024)
        val tag = Argon2id.hash(ByteArray(32) { 1 }, ByteArray(16) { 2 }, 3, 32, 4, 32, ByteArray(8) { 3 }, ByteArray(12) { 4 }, memory)
        assertEquals("0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659", tag.hex())
        for (i in 0 until memory.capacity()) assertEquals("byte $i", 0.toByte(), memory.get(i))
    }

    /** Also when the computation is interrupted. */
    @Test
    fun workingMemoryIsZeroedWhenInterrupted() {
        val memory = ByteBuffer.allocateDirect(8 * 1024 * 1024)
        val worker = Thread {
            runCatching {
                Argon2id.hash(ByteArray(32) { 1 }, ByteArray(16), 1000, 8 * 1024, 4, 32, memory = memory) { done, _ ->
                    if (done == 4) Thread.currentThread().interrupt()
                }
            }
        }
        worker.start()
        worker.join(30_000)
        assertTrue("still running", !worker.isAlive)
        for (i in 0 until memory.capacity() step 8) assertEquals("word at $i", 0L, memory.getLong(i))
    }

    /**
     * Interrupting must stop the computation and return only once no thread can still write
     * to the memory, which the app unmaps right after: a late write is a native crash there.
     */
    @Test
    fun interruptStopsAndLeavesNoWriterBehind() {
        val memory = ByteBuffer.allocateDirect(64 * 1024 * 1024)
        val started = CountDownLatch(1)
        val outcome = AtomicReference<Throwable?>()
        val worker = Thread {
            try {
                Argon2id.hash(ByteArray(32), ByteArray(16), 1000, 64 * 1024, 4, 32, memory = memory) { done, _ ->
                    if (done == 8) started.countDown()
                }
            } catch (e: Throwable) {
                outcome.set(e)
            }
        }
        worker.start()
        started.await()
        worker.interrupt()
        worker.join(10_000)
        assertTrue("still running", !worker.isAlive)
        assertTrue("threw ${outcome.get()}", outcome.get() is InterruptedException)
        val lanes = Thread.getAllStackTraces().keys.filter { it.name == Argon2id.THREAD_NAME && it.isAlive }
        assertTrue("${lanes.size} lane threads outlived hash()", lanes.isEmpty())
    }

    /** Random parameters against argon2-cffi (reference/make_fixtures.py). */
    @Test
    fun matchesReferenceImplementation() {
        val rows = fixture("argon2id.tsv")
        assertEquals(48, rows.size)
        for (row in rows) {
            val (t, m, p) = row.take(3).map(String::toInt)
            val got = Argon2id.hash(row[3].unhex(), row[4].unhex(), t, m, p, tagLength = row[5].toInt())
            assertEquals("t=$t m=$m p=$p", row[6], got.hex())
        }
    }
}
