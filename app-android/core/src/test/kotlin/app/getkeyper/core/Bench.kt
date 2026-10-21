package app.getkeyper.core

/**
 * Argon2id wall-clock time for candidate parameters. Arguments: "t:mKiB:p" triples
 * (default: Keyper's own). Runs on the desktop JVM via `./gradlew :core:bench`, and on
 * a device through app_process (see README).
 */
fun main(args: Array<String>) {
    val configs = args.ifEmpty { arrayOf("${Keyper.ITERATIONS}:${Keyper.MEMORY_KIB}:${Keyper.PARALLELISM}") }
    val password = ByteArray(32)
    val salt = ByteArray(16)
    for (config in configs) {
        val (t, m, p) = config.split(':').map(String::toInt)
        Argon2id.hash(password, salt, 1, minOf(m, 16 * 1024), p, 32) // warm up the JIT
        val times = List(3) {
            val start = System.nanoTime()
            Argon2id.hash(password, salt, t, m, p, 32)
            (System.nanoTime() - start) / 1e6
        }
        val best = times.min()
        val mibPerSecond = t * m / 1024.0 / (best / 1000)
        println("t=$t m=${m / 1024}MiB p=$p  best %.0f ms  (runs: %s)  %.0f MiB/s".format(best, times.joinToString { "%.0f".format(it) }, mibPerSecond))
    }
}
