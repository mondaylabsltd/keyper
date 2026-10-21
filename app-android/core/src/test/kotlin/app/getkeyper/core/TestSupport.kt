package app.getkeyper.core

fun String.unhex(): ByteArray = chunked(2).map { it.toInt(16).toByte() }.toByteArray()

fun ByteArray.hex(): String = joinToString("") { "%02x".format(it) }

/** Rows of a tab-separated fixture in src/test/resources, without the # header. */
fun fixture(name: String): List<List<String>> =
    object {}.javaClass.getResource("/$name")!!.readText().lines()
        .filter { it.isNotEmpty() && !it.startsWith("#") }
        .map { it.split('\t') }
