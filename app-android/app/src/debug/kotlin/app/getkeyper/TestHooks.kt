package app.getkeyper

import java.security.MessageDigest

/**
 * Debug builds only: lets the instrumented tests (src/androidTest) drive what they cannot
 * otherwise control on an emulator in a repeatable way. Release builds compile
 * src/release/.../TestHooks.kt instead, whose hooks are constant nulls that R8 folds away, so a
 * released APK has no switch of any kind: no field, no intent extra, no exported component.
 *
 * Every hook is null by default, and null means the real behaviour.
 *
 * The tests in :backgroundtest run in a process of their own, so that Keyper's process can be
 * cached, frozen and killed as on a real phone; they cannot reach these fields. For them, two
 * hooks also read a `debug.keyper.*` system property, which `adb shell setprop` (or the test, as
 * the shell) sets and clears: [clipboardMs] and [derive].
 */
internal object TestHooks {
    /** Replaces the radio readings: [airplane mode on, Wi-Fi on, Bluetooth on]. */
    @Volatile var radios: (() -> List<Boolean>)? = null

    /**
     * Replaces the minute-long 1 GiB derivation of the key K from (email, secret), on the worker
     * thread. It may sleep, to stand for a derivation in flight, or throw, to reach the error dialog.
     * With `debug.keyper.fake_derive` set to 1, a stand-in key computed at once.
     */
    @Volatile var derive: ((email: String, secret: String) -> ByteArray)? = null
        get() = field ?: if (property("debug.keyper.fake_derive") == "1") ::fakeKey else null

    /**
     * Replaces [CLIPBOARD_MS], so that a test need not wait a minute to see the clipboard cleared.
     * Falls back to `debug.keyper.clipboard_ms`.
     */
    @Volatile var clipboardMs: Long? = null
        get() = field ?: property("debug.keyper.clipboard_ms")?.toLongOrNull()?.takeIf { it > 0 }

    /** A line in logcat (tag KeyperTest) for the tests to observe; never anything typed or derived. */
    fun log(message: String) {
        android.util.Log.i("KeyperTest", message)
    }

    /** The same stand-in as KeyperRule.fakeKey: any 32 bytes that depend on both inputs. */
    private fun fakeKey(email: String, secret: String): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(
            "test key\n${app.getkeyper.core.Keyper.normalizeEmail(email)}\n${app.getkeyper.core.Keyper.normalizeSecret(secret)}".toByteArray())

    /** Read through getprop, which any app may run; empty or unset reads as null. */
    private fun property(name: String): String? = runCatching {
        val process = ProcessBuilder("getprop", name).redirectErrorStream(true).start()
        process.inputStream.bufferedReader().use { it.readText() }.trim().also { process.waitFor() }
    }.getOrNull()?.ifEmpty { null }
}
