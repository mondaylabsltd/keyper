package app.getkeyper

import android.app.Instrumentation
import android.content.ClipData
import android.content.ClipboardManager
import android.graphics.Bitmap
import android.os.ParcelFileDescriptor
import android.os.PersistableBundle
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.EditText
import android.widget.GridLayout
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.PerformException
import androidx.test.espresso.ViewAssertion
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.espresso.matcher.ViewMatchers.withId
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleCallback
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import app.getkeyper.core.Keyper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.rules.TestRule
import org.junit.runner.Description
import org.junit.runners.model.Statement
import java.security.MessageDigest

/** [airplane mode on, Wi-Fi on, Bluetooth on], as [TestHooks.radios] reports them. */
val OFFLINE = listOf(true, false, false)
val AIRPLANE_OFF = listOf(false, false, false)
val WIFI_ON = listOf(true, true, false)
val BLUETOOTH_ON = listOf(true, false, true)

const val EMAIL = "alice@example.com"
/** Lowercase words only, so that it types without shift; strong enough to skip the weak warning. */
const val SECRET = "seven quiet lanterns drift over the harbor at midnight"
const val WEAK_SECRET = "aaaaaaaaaaaa"

/**
 * Launches [MainActivity] with the debug build's [TestHooks] set: the radios report [radios]
 * (offline unless a test says otherwise), and the derivation is replaced by [fakeKey], so that a
 * phrase appears at once instead of after a minute of 1 GiB Argon2id. [realRadios] and
 * [realDerivation] leave the corresponding hook unset. Every hook is reset afterwards.
 */
class KeyperRule(
    private val realRadios: Boolean = false,
    private val realDerivation: Boolean = false,
    private val launch: Boolean = true,
) : TestRule {
    val instrumentation: Instrumentation = InstrumentationRegistry.getInstrumentation()
    val context get() = instrumentation.targetContext
    @Volatile var radios = OFFLINE
    /** How long the fake derivation takes, to stand for one in flight. */
    @Volatile var deriveMs = 0L
    /** When set, the fake derivation throws it, as a failed derivation would. */
    @Volatile var deriveError: Throwable? = null
    /** How many derivations the screen started. */
    @Volatile var derivations = 0
    lateinit var scenario: ActivityScenario<MainActivity>

    override fun apply(base: Statement, description: Description) = object : Statement() {
        override fun evaluate() {
            if (!realRadios) TestHooks.radios = { radios }
            if (!realDerivation) TestHooks.derive = { email, secret ->
                derivations++
                SystemClock.sleep(deriveMs)
                deriveError?.let { throw it }
                fakeKey(email, secret)
            }
            TestHooks.clipboardMs = null
            TestHooks.suppressClipboardOverlay = true // emulators only; see TestHooks
            onMain { Copied.reset(context) } // each test starts a fresh session: the first copy warns
            try {
                if (launch) launch()
                base.evaluate()
            } finally {
                if (::scenario.isInitialized) {
                    runCatching { onMain { clipboard.clearPrimaryClip() } }
                    scenario.close()
                }
                ActivityLifecycleMonitorRegistry.getInstance().removeLifecycleCallback(stopWatcher)
                TestHooks.radios = null
                TestHooks.derive = null
                TestHooks.clipboardMs = null
                TestHooks.suppressClipboardOverlay = null
            }
        }
    }

    /** When (uptime) Keyper's screen was stopped during the test: leaving wipes the phrase, so a stop the test did not ask for explains a vanished phrase. */
    val stops: MutableList<Long> = java.util.Collections.synchronizedList(mutableListOf())
    private val stopWatcher = ActivityLifecycleCallback { activity, stage ->
        if (activity is MainActivity && stage == Stage.STOPPED) stops += SystemClock.uptimeMillis()
    }

    fun launch() {
        prepareDevice()
        ActivityLifecycleMonitorRegistry.getInstance().addLifecycleCallback(stopWatcher)
        scenario = ActivityScenario.launch(MainActivity::class.java)
        waitFor("Keyper in front with window focus", 30_000) { read { it.hasWindowFocus() } }
        if (realRadios) instrumentation.waitForIdleSync() else awaitOffline(radios == OFFLINE)
    }

    /**
     * Keeps other windows from taking focus from Keyper mid-test, which would make Android deny it
     * the clipboard and refuse the injected touches: on a loaded emulator, another app's "not
     * responding" dialog; and on Android 13+, the system's clipboard overlay, which is focusable and
     * appears after every copy. Settings of the test device only, re-applied on every launch since the
     * system may sync device_config back.
     */
    private fun prepareDevice() {
        shell("settings put global hide_error_dialogs 1")
        shell("device_config put systemui clipboard_overlay_enabled false")
        shell("am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS")
    }

    /** Runs [block] on the main thread with the activity and returns its result. */
    fun <T> read(block: (MainActivity) -> T): T {
        var value: Result<T>? = null
        scenario.onActivity { value = runCatching { block(it) } }
        return value!!.getOrThrow()
    }

    fun <T> onMain(block: () -> T): T {
        var value: Result<T>? = null
        instrumentation.runOnMainSync { value = runCatching(block) }
        return value!!.getOrThrow()
    }

    fun <V : View> view(id: Int): V = read { it.findViewById<V>(id) }
    fun text(id: Int): String = read { it.findViewById<TextView>(id).text.toString() }
    fun shown(id: Int): Boolean = read { it.findViewById<View>(id).visibility == View.VISIBLE }
    /** Shown on screen: the view and every parent visible (the page it is on, too). */
    fun onScreen(id: Int): Boolean = read { it.findViewById<View>(id)?.isShown == true }
    fun enabled(id: Int): Boolean = read { it.findViewById<View>(id).isEnabled }
    private fun offlineCardHidden() = read { it.findViewById<View>(R.id.offline_card).visibility != View.VISIBLE }

    /** Sets the radios and waits for the screen's poll (every 500 ms) to pick them up. */
    fun switchRadios(state: List<Boolean>) {
        radios = state
        awaitOffline(state == OFFLINE)
    }

    fun awaitOffline(offline: Boolean) =
        waitFor("offline=$offline") { offlineCardHidden() == offline && enabled(R.id.secret) == offline }

    // --- Typing on Keyper's own keyboard, through real touches -------------------------------------

    /** Taps the field, which opens Keyper's keyboard on it. */
    fun focus(id: Int) {
        onView(withId(id)).perform(scrollTo(), click())
        waitFor("keyboard open") { shown(R.id.keyboard_slot) && read { it.findViewById<View>(id).hasFocus() } }
    }

    /**
     * Types [text] key by key on Keyper's keyboard, as touches injected into the window at each
     * key's position: lowercase letters, space, and `@` `.` in the email.
     */
    fun typeKeys(text: String) {
        val space = context.getString(R.string.key_space)
        for (c in text) {
            val description = if (c == ' ') space else c.toString()
            val (x, y) = read { a ->
                val key = findShown(a.findViewById(R.id.keyboard_slot), description) ?: error("no key '$description' shown")
                val at = IntArray(2).also(key::getLocationOnScreen)
                (at[0] + key.width / 2f) to (at[1] + key.height / 2f)
            }
            tapAt(x, y)
        }
        instrumentation.waitForIdleSync()
    }

    fun tapAt(x: Float, y: Float) {
        val down = SystemClock.uptimeMillis()
        for ((action, time) in listOf(MotionEvent.ACTION_DOWN to down, MotionEvent.ACTION_UP to down + 10)) {
            val event = MotionEvent.obtain(down, time, action, x, y, 0)
            event.source = InputDevice.SOURCE_TOUCHSCREEN
            instrumentation.sendPointerSync(event)
            event.recycle()
        }
    }

    /** A real touch at the centre of the view, whatever its state; unlike Espresso's click, it never refuses a disabled view. */
    fun touch(id: Int) {
        val (x, y) = read { a ->
            val v = a.findViewById<View>(id)
            val at = IntArray(2).also(v::getLocationOnScreen)
            (at[0] + v.width / 2f) to (at[1] + v.height / 2f)
        }
        tapAt(x, y)
        instrumentation.waitForIdleSync()
    }

    private fun findShown(view: View, description: String): View? {
        if (view.isShown && view.contentDescription?.toString() == description) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) findShown(view.getChildAt(i), description)?.let { return it }
        return null
    }

    /** Empties both fields (test setup, not typing), then types both on Keyper's keyboard. */
    fun fillInputs(email: String = EMAIL, secret: String = SECRET, emailId: Int = R.id.email, secretId: Int = R.id.secret) {
        read { a -> listOf(emailId, secretId).forEach { a.findViewById<EditText>(it).text.clear() } }
        focus(emailId)
        typeKeys(email)
        focus(secretId)
        typeKeys(secret)
        waitFor("typed") { text(emailId) == email && text(secretId) == secret }
    }

    /** The same, in the recovery drill's own fields. */
    fun fillDrill(email: String = EMAIL, secret: String = SECRET) =
        fillInputs(email, secret, R.id.drill_email, R.id.drill_secret)

    fun tap(id: Int) {
        try {
            onView(withId(id)).perform(scrollTo(), click())
        } catch (e: PerformException) {
            throw AssertionError("could not tap ${context.resources.getResourceEntryName(id)}${stopsNote()}", e)
        }
    }

    /**
     * Why a view may be gone: Keyper's screen was stopped during the test, and leaving wipes the
     * phrase by design. On the CI emulator's 320x640 screen, SystemUI's clipboard overlay crashed
     * after a copy (ArrayIndexOutOfBoundsException in StaticLayout), which stops the app in front.
     */
    fun stopsNote(): String =
        if (stops.isEmpty()) "" else "; Keyper's screen was stopped ${stops.size}× during the test (which wipes the phrase): see logcat for what took over, e.g. a SystemUI crash"

    /** Taps Copy, confirming the warning that the first copy of a session shows. */
    fun copy() {
        val warns = !onMain { Copied.warned }
        tap(R.id.copy)
        if (warns) onView(withId(android.R.id.button1)).inRoot(isDialog()).perform(click())
        instrumentation.waitForIdleSync()
    }

    /** Types the inputs, taps Generate and waits for the phrase; returns the words shown. */
    fun derivePhrase(email: String = EMAIL, secret: String = SECRET): List<String> {
        fillInputs(email, secret)
        tap(R.id.generate)
        return awaitPhrase(12)
    }

    fun awaitPhrase(words: Int, timeoutMs: Long = 10_000): List<String> {
        waitFor("phrase of $words words", timeoutMs) { onScreen(R.id.result) && shownWords().size == words }
        // The screen then scrolls to the phrase; a touch during that scroll only stops it (ScrollView
        // takes it), so a tap on Copy at that moment would be lost. Wait until it has come to rest.
        var last = Int.MIN_VALUE
        waitFor("screen at rest") { read { it.findViewById<View>(R.id.scroll).scrollY }.let { y -> (y == last).also { last = y } } }
        return shownWords()
    }

    /** The words in the phrase grid, as displayed ("01  word"). */
    fun shownWords(): List<String> = read { activity ->
        val grid = activity.findViewById<GridLayout>(R.id.words)
        (0 until grid.childCount).map { (grid.getChildAt(it) as TextView).text.toString().substringAfterLast(' ') }
    }

    /** The phrase is not on screen: its card is hidden, or the page it is on is. */
    fun phraseHidden() = !onScreen(R.id.result)

    // --- Clipboard: what it really holds, whichever window has focus ----------------------------------

    val clipboard: ClipboardManager get() = context.getSystemService(ClipboardManager::class.java)

    /**
     * Runs [read] on the main thread with the shell's READ_CLIPBOARD_IN_BACKGROUND adopted, dropped
     * again at once. Without it Android 10+ answers an app without window focus as if the clipboard
     * were empty (logging "Denying clipboard access"), so "unreadable" would look like "cleared": on
     * CI, after SystemUI crashed and took focus, another app's clip read back as null although Keyper
     * had logged "clear: another clip, kept". Keyper's own code cannot run during the block (it runs
     * on the main thread too), so the app under test keeps its real, focus-bound access.
     */
    fun <T> readClipboard(read: (ClipboardManager) -> T): T = onMain {
        val automation = instrumentation.uiAutomation
        automation.adoptShellPermissionIdentity(READ_CLIPBOARD_IN_BACKGROUND)
        try {
            read(clipboard)
        } finally {
            automation.dropShellPermissionIdentity()
        }
    }

    /** The clipboard's text, or null when it is empty (never because it could not be read). */
    fun clipText(): String? = readClipboard { cb ->
        if (!cb.hasPrimaryClip()) null
        else cb.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString()?.ifEmpty { null }
    }

    fun clipLabel(): String? = readClipboard { it.primaryClipDescription?.label?.toString() }

    /**
     * Another app's clip, copied after Keyper's, and read back at once: proof that a later null is an
     * empty clipboard. On an emulator it asks SystemUI not to show its clipboard overlay for it.
     */
    fun copyOther(label: String = "notes", text: String = "groceries: milk, eggs") {
        onMain {
            clipboard.setPrimaryClip(ClipData.newPlainText(label, text).apply {
                description.extras = PersistableBundle().apply { putBoolean(SUPPRESS_OVERLAY, true) }
            })
        }
        assertEquals("another app's clip did not read back", text, clipText())
    }

    // --- System state -----------------------------------------------------------------------------

    fun shell(command: String): String {
        val pfd = instrumentation.uiAutomation.executeShellCommand(command)
        return ParcelFileDescriptor.AutoCloseInputStream(pfd).use { it.readBytes().decodeToString() }
    }

    /**
     * A screenshot of the display as the system composes it for capture, in which a window with
     * FLAG_SECURE comes out black (as with `adb shell screencap`). NoScreenshotsTest's control shows
     * the same call does capture Keyper's window once the test clears its flag.
     *
     * Null when the system refuses the capture altogether. HyperOS does that while any FLAG_SECURE
     * window is on screen, where AOSP draws the window black instead: on a Redmi K40
     * (HyperOS 1.0, Android 13), `adb shell screencap` exits 1 with no image while Keyper is in
     * front, and captures normally once it is not.
     */
    fun screenshotOrNull(): Bitmap? = instrumentation.uiAutomation.takeScreenshot()

    fun waitFor(what: String, timeoutMs: Long = 5_000, condition: () -> Boolean) {
        val end = SystemClock.uptimeMillis() + timeoutMs
        while (true) {
            instrumentation.waitForIdleSync()
            if (condition()) return
            if (SystemClock.uptimeMillis() > end) fail("timed out waiting for $what")
            SystemClock.sleep(50)
        }
    }

    companion object {
        const val READ_CLIPBOARD_IN_BACKGROUND = "android.permission.READ_CLIPBOARD_IN_BACKGROUND"
        /** SystemUI skips its clipboard overlay for a clip with this extra, on emulators only (ClipboardListener). */
        const val SUPPRESS_OVERLAY = "com.android.systemui.SUPPRESS_CLIPBOARD_OVERLAY"

        /** A stand-in for K: any 32 bytes that depend on both inputs. */
        fun fakeKey(email: String, secret: String): ByteArray =
            MessageDigest.getInstance("SHA-256")
                .digest("test key\n${Keyper.normalizeEmail(email)}\n${Keyper.normalizeSecret(secret)}".toByteArray())

        fun expectedPhrase(words: Int, email: String = EMAIL, secret: String = SECRET) =
            Keyper.mnemonic(fakeKey(email, secret), words)

        /** Asserts that the window holding the matched view has FLAG_SECURE. */
        val secureWindow = ViewAssertion { view, missing ->
            if (missing != null) throw missing
            val params = view.rootView.layoutParams as WindowManager.LayoutParams
            assertTrue("FLAG_SECURE missing on window '${params.title}'", params.flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
        }

        fun EditText.value() = text.toString()
    }
}
