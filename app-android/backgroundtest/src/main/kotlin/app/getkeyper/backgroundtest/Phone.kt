package app.getkeyper.backgroundtest

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.graphics.Rect
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.fail
import org.junit.rules.TestRule
import org.junit.runner.Description
import org.junit.runners.model.Statement

/** Keyper's debug build, the app under test; it runs in a process of its own, beside this one. */
const val KEYPER = "app.getkeyper.private"

const val EMAIL = "alice@example.com"
/** Lowercase words only, so that it types without shift; strong enough to skip the weak warning. */
const val SECRET = "seven quiet lanterns drift over the harbor at midnight"

/** This APK's own window, brought to the front to read the clipboard. Never Keyper's. */
class ClipReader : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "ClipReader"
    }
}

/** What the clipboard holds, as the app in front sees it. */
data class Clip(val label: String?, val text: String?, val timestamp: Long)

/**
 * Drives Keyper from outside its process, as a user and the phone would: real touches injected
 * through UiAutomation, real radios toggled by shell, Home, the system's own freezer and kill. Keyper's
 * debug build reads two `debug.keyper.*` properties set here: a stand-in derivation (instead of a
 * minute of 1 GiB Argon2id) and, when a test asks for one, a shorter clipboard lifetime.
 *
 * Every test starts with Keyper force-stopped, the radios off and the clipboard empty, and ends
 * with all of it undone.
 */
class Phone : TestRule {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val context get() = instrumentation.targetContext
    private val ua get() = instrumentation.uiAutomation
    private val clipboard get() = context.getSystemService(ClipboardManager::class.java)
    private var radios: List<String>? = null
    private val readers = mutableListOf<ClipReader>()

    override fun apply(base: Statement, description: Description) = object : Statement() {
        override fun evaluate() {
            prepare()
            try {
                base.evaluate()
            } finally {
                cleanUp()
            }
        }
    }

    private fun prepare() {
        ua.serviceInfo = ua.serviceInfo.apply { flags = flags or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS }
        shell("am force-stop $KEYPER")
        shell("setprop debug.keyper.fake_derive 1")
        clipboardLifetime(null)
        // As KeyperRule: no "not responding" dialog or clipboard overlay may take focus mid-test.
        shell("settings put global hide_error_dialogs 1")
        shell("device_config put systemui clipboard_overlay_enabled false")
        shell("am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS")
        radios = listOf(shell("settings get global airplane_mode_on").trim(), shell("settings get global wifi_on").trim())
        shell("cmd connectivity airplane-mode enable")
        shell("svc wifi disable")
        shell("cmd bluetooth_manager disable")
        waitFor("radios off", 20_000) {
            shell("settings get global airplane_mode_on").trim() == "1" && shell("settings get global wifi_on").trim() in setOf("0", "3")
        }
        shell("logcat -c")
        withReader { it.wipe() }
    }

    private fun cleanUp() {
        runCatching { withReader { it.wipe() } }
        shell("setprop debug.keyper.fake_derive 0")
        clipboardLifetime(null)
        shell("am force-stop $KEYPER")
        home()
        onMain { readers.forEach(Activity::finish); readers.clear() }
        val (airplane, wifi) = radios ?: return
        if (airplane != "1") shell("cmd connectivity airplane-mode disable")
        if (wifi in setOf("1", "2")) shell("svc wifi enable")
    }

    /** Shortens Keyper's clipboard lifetime (debug builds only); null restores the real minute. */
    fun clipboardLifetime(ms: Long?) {
        shell("setprop debug.keyper.clipboard_ms ${ms ?: 0}")
    }

    // --- Keyper, in front ---------------------------------------------------------------------------

    fun launchKeyper() {
        shell("am start -W -n $KEYPER/app.getkeyper.MainActivity")
        // The fields are enabled once Keyper has read the radios as off.
        waitFor("Keyper in front, offline", 30_000) { root()?.packageName == KEYPER && node("email")?.isEnabled == true }
    }

    private fun root(): AccessibilityNodeInfo? = ua.rootInActiveWindow

    fun node(id: String): AccessibilityNodeInfo? =
        root()?.findAccessibilityNodeInfosByViewId("$KEYPER:id/$id")?.firstOrNull()

    private fun nodeByDescription(description: String, from: AccessibilityNodeInfo? = root()): AccessibilityNodeInfo? {
        from ?: return null
        if (from.contentDescription?.toString() == description && from.isVisibleToUser) return from
        for (i in 0 until from.childCount) nodeByDescription(description, from.getChild(i))?.let { return it }
        return null
    }

    /** A real touch at the centre of the view, scrolled on screen first. */
    fun tap(node: AccessibilityNodeInfo) {
        if (!node.isVisibleToUser) {
            node.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SHOW_ON_SCREEN.id)
            SystemClock.sleep(500)
            node.refresh()
        }
        val r = Rect().also(node::getBoundsInScreen)
        val (x, y) = r.exactCenterX() to r.exactCenterY()
        android.util.Log.i("Phone", "tap ${node.viewIdResourceName ?: node.contentDescription} at $r visible=${node.isVisibleToUser}")
        val down = SystemClock.uptimeMillis()
        for ((action, time) in listOf(MotionEvent.ACTION_DOWN to down, MotionEvent.ACTION_UP to down + 20)) {
            val event = MotionEvent.obtain(down, time, action, x, y, 0)
            event.source = InputDevice.SOURCE_TOUCHSCREEN
            check(ua.injectInputEvent(event, true)) { "touch at ($x, $y) refused" }
            event.recycle()
        }
        SystemClock.sleep(150)
    }

    fun tap(id: String) = tap(awaitNode(id))

    fun awaitNode(id: String, timeoutMs: Long = 10_000): AccessibilityNodeInfo {
        var found: AccessibilityNodeInfo? = null
        waitFor("view $id", timeoutMs) { node(id)?.also { found = it } != null }
        return found!!
    }

    /** Taps the field, then types [text] key by key on Keyper's own keyboard. */
    fun type(field: String, text: String) {
        // A loaded emulator may drop a touch: tap again until Keyper's keyboard is open on the field.
        var opened = false
        for (attempt in 1..4) {
            tap(field)
            opened = runCatching { waitFor("keyboard open", 5_000) { node("keyboard_slot")?.isVisibleToUser == true && node(field)?.isFocused == true } }.isSuccess
            if (opened) break
        }
        check(opened) { "Keyper's keyboard did not open on $field" }
        val space = keyperString("key_space")
        for (c in text) {
            val description = if (c == ' ') space else c.toString()
            var key: AccessibilityNodeInfo? = null
            waitFor("key '$description'") { nodeByDescription(description)?.also { key = it } != null }
            tap(key!!)
        }
    }

    /** Types the inputs, taps Generate (Back closes the keyboard first) and waits for the phrase. */
    fun derivePhrase() {
        type("email", EMAIL)
        type("secret", SECRET)
        ua.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
        waitFor("keyboard closed") { node("keyboard_slot")?.isVisibleToUser != true }
        tap("generate")
        waitFor("phrase shown", 20_000) { node("copy")?.isVisibleToUser == true }
        SystemClock.sleep(1_000) // the screen scrolls to the phrase
    }

    /** Taps Copy; on the first copy of a session, confirms the warning. */
    fun copy() {
        val copies = copies()
        tap("copy")
        // The first copy of a session asks first: confirm "Copy" in Keyper's warning.
        waitFor("Keyper copied or warned", 15_000) { copies() > copies || warning() != null }
        warning()?.let(::tap)
        waitFor("Keyper copied", 15_000) { copies() > copies }
    }

    private fun warning(): AccessibilityNodeInfo? =
        root()?.takeIf { it.packageName == KEYPER }?.findAccessibilityNodeInfosByViewId("android:id/button1")?.firstOrNull()

    /** How many copies Keyper's debug log reports so far. */
    private fun copies() = keyperLog().lines().count { "copied:" in it }

    private fun keyperString(name: String): String {
        val resources = context.packageManager.getResourcesForApplication(KEYPER)
        return resources.getString(resources.getIdentifier(name, "string", KEYPER))
    }

    fun keyperLabel() = keyperString("result_title")

    // --- The phone ----------------------------------------------------------------------------------

    fun home() {
        ua.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
        SystemClock.sleep(500)
    }

    /**
     * The user leaves Keyper for other apps: Home, then Settings, then this APK's window. Keyper is
     * then no longer the "previous" app, which Android keeps out of the cache, so its process becomes
     * cached, where the system freezes it (Android 12+) and may kill it. Returns with the reader in front.
     */
    fun leaveKeyperForOtherApps() {
        home()
        shell("am start -W -a android.settings.SETTINGS")
        SystemClock.sleep(1_000)
        withReader { }
        waitFor("Keyper's process cached", 30_000) { cached(processRecord()) || pid().isEmpty() }
    }

    /**
     * Cached, by the record's own flag or by its process state (CAC, CACC, CRE, CEM: the cached
     * states). HyperOS never sets the flag: on a Redmi K40 (HyperOS 1.0) Keyper's record shows
     * `state: cur=CAC` with `cached=false` for as long as it stays in the background.
     */
    private fun cached(record: String) = "cached=true" in record || CACHED_STATE.containsMatchIn(record)

    /** Whether this device runs the cached-apps freezer (on by default from Android 12 or 13, depending on the device). */
    fun freezerEnabled() = "use_freezer=true" in shell("dumpsys activity settings")

    fun pid(): String = shell("pidof $KEYPER").trim()

    /** Keyper's process record, as `dumpsys activity processes` prints it. */
    fun processRecord(): String = shell("dumpsys activity processes $KEYPER")

    fun frozen() = "isFrozen=true" in processRecord()

    /** Waits for the system's own freezer to freeze Keyper's cached process (a 10 s debounce on Android 14). */
    fun awaitFrozen(timeoutMs: Long = 60_000) = waitFor("Keyper's process frozen", timeoutMs) { frozen() }

    /** As a phone short of memory does to a cached app (not a force-stop, which cancels everything). */
    fun killInBackground() {
        val pid = pid()
        check(pid.isNotEmpty()) { "Keyper is not running" }
        shell("am kill $KEYPER")
        waitFor("Keyper's process $pid gone", 10_000) { pid() != pid }
    }

    // --- The clipboard, from this APK's own window in front -----------------------------------------

    fun <T> withReader(block: (ClipboardManager) -> T): T {
        val reader = instrumentation.startActivitySync(Intent(context, ClipReader::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)) as ClipReader
        onMain { readers += reader }
        waitFor("reader in front with focus", 20_000) { onMain { reader.hasWindowFocus() } }
        return onMain { block(clipboard) }
    }

    fun readClip(): Clip? = withReader { cb ->
        cb.primaryClipDescription?.let { d -> Clip(d.label?.toString(), cb.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString(), d.timestamp) }
    }

    /** Another app's clip, copied while this APK is in the background: writing needs no focus. */
    fun copyOtherFromBackground(label: String = "notes", text: String = "groceries: milk, eggs") =
        onMain { clipboard.setPrimaryClip(ClipData.newPlainText(label, text)) }

    /** Another app's clip, copied from this APK's window. */
    fun copyOther(label: String = "notes", text: String = "groceries: milk, eggs") =
        withReader { it.setPrimaryClip(ClipData.newPlainText(label, text)) }

    private fun ClipboardManager.wipe() {
        if (android.os.Build.VERSION.SDK_INT >= 28) clearPrimaryClip() else setPrimaryClip(ClipData.newPlainText("", ""))
    }

    /** Keyper's debug log lines (tag KeyperTest): never anything typed or derived. */
    fun keyperLog(): String = shell("logcat -d -s KeyperTest:I")

    // --- Plumbing -----------------------------------------------------------------------------------

    fun shell(command: String): String {
        val pfd = ua.executeShellCommand(command)
        return ParcelFileDescriptor.AutoCloseInputStream(pfd).use { it.readBytes().decodeToString() }
    }

    fun <T> onMain(block: () -> T): T {
        var value: Result<T>? = null
        instrumentation.runOnMainSync { value = runCatching(block) }
        return value!!.getOrThrow()
    }

    fun waitFor(what: String, timeoutMs: Long = 5_000, condition: () -> Boolean) {
        val end = SystemClock.uptimeMillis() + timeoutMs
        while (true) {
            if (runCatching(condition).getOrDefault(false)) return
            if (SystemClock.uptimeMillis() > end) fail("timed out waiting for $what")
            SystemClock.sleep(200)
        }
    }
}

private val CACHED_STATE = Regex("""state: cur=(CAC|CACC|CRE|CEM)\b""")
