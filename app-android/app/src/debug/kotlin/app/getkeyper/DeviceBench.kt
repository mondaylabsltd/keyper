package app.getkeyper

import android.os.SharedMemory
import app.getkeyper.core.Argon2id
import app.getkeyper.core.Keyper

/**
 * Argon2id timing on a device with the app's own off-heap memory (debug builds only).
 * Arguments are "t:mKiB:p[:runs]", defaulting to Keyper's parameters and 4 runs:
 *
 *   adb shell 'CLASSPATH=$(pm path app.getkeyper.private | cut -d: -f2) app_process / app.getkeyper.DeviceBenchKt'
 *
 * The first run is cold (interpreted until the JIT kicks in), like a fresh app launch.
 */
fun main(args: Array<String>) {
    val configs = args.ifEmpty { arrayOf("${Keyper.ITERATIONS}:${Keyper.MEMORY_KIB}:${Keyper.PARALLELISM}") }
    for (config in configs) {
        val fields = config.split(':').map(String::toInt)
        val (t, m, p) = fields
        val times = List(fields.getOrElse(3) { 4 }) {
            SharedMemory.create("bench", m * 1024).use { shm ->
                val memory = shm.mapReadWrite()
                try {
                    val start = System.nanoTime()
                    Argon2id.hash(ByteArray(32), ByteArray(16), t, m, p, 32, memory = memory)
                    (System.nanoTime() - start) / 1e6
                } finally {
                    SharedMemory.unmap(memory)
                }
            }
        }
        println("t=$t m=${m / 1024}MiB p=$p  runs: %s ms".format(times.joinToString { "%.0f".format(it) }))
    }
}
