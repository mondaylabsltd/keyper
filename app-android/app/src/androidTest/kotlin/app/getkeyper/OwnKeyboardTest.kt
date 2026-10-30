package app.getkeyper

import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Bundle
import android.os.SystemClock
import android.text.InputType
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityNodeInfo.AccessibilityAction
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.LinearLayout
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Claim 1, "its own keyboard": the input fields never connect to the system keyboard (IME), so no
 * keyboard app can log or sync what is typed, and nothing but Keyper's keyboard can enter text.
 */
@RunWith(AndroidJUnit4::class)
class OwnKeyboardTest {
    @get:Rule val k = KeyperRule()

    private val fields = listOf(R.id.email, R.id.secret)
    private val imm get() = k.context.getSystemService(InputMethodManager::class.java)

    private fun acceptingText() = k.onMain { imm.isAcceptingText }
    private fun imeVisible() = k.read { it.window.decorView.rootWindowInsets.isVisible(WindowInsets.Type.ime()) }
    private fun imeDump() = k.shell("dumpsys input_method")

    @Test
    fun fieldsHandTheSystemKeyboardNoInputConnection() = k.read { activity ->
        for (id in fields + listOf(R.id.drill_email, R.id.drill_secret)) { // the drill page's too
            val field = activity.findViewById<KeyperField>(id)
            assertNull(field.onCreateInputConnection(EditorInfo()))
            assertEquals(InputType.TYPE_NULL, field.inputType)
            assertFalse(field.showSoftInputOnFocus)
        }
    }

    @Test
    fun focusingAFieldOpensKeypersKeyboardAndNeverTheSystemOne() {
        for (id in fields) {
            k.focus(id)
            SystemClock.sleep(1500) // time for a system keyboard to come up, were it going to
            assertTrue("Keyper's keyboard is open", k.shown(R.id.keyboard_slot))
            assertFalse("an IME has an input connection", acceptingText())
            assertFalse("the IME is visible", imeVisible())
            val dump = imeDump()
            assertTrue(dump, "mInputShown=false" in dump)
            if ("mServedInputConnection=" in dump) assertTrue(dump, "mServedInputConnection=null" in dump)
        }
    }

    /** The control for the test above: the very same checks do see a system keyboard on a plain EditText. */
    @Test
    fun theSameChecksSeeTheSystemKeyboardOnAPlainEditText() {
        val plain = View.generateViewId()
        k.read { a -> a.findViewById<LinearLayout>(R.id.root).addView(EditText(a).apply { id = plain }, 0) }
        k.read { a -> a.findViewById<View>(plain).requestFocus() }
        k.onMain { imm.showSoftInput(k.view(plain), 0) }
        k.waitFor("system keyboard on a plain EditText", 10_000) { acceptingText() && imeVisible() }
        assertTrue(imeDump().contains("mInputShown=true"))
    }

    /** Even if something forces the system keyboard up over a Keyper field, it gets nothing to type into. */
    @Test
    fun aForcedSystemKeyboardStillGetsNoConnection() {
        for (id in fields) {
            k.focus(id)
            k.onMain { imm.showSoftInput(k.view(id), InputMethodManager.SHOW_IMPLICIT) }
            SystemClock.sleep(1500)
            assertFalse(acceptingText())
            val dump = imeDump()
            if ("mServedInputConnection=" in dump) assertTrue(dump, "mServedInputConnection=null" in dump)
            if ("mStartedInputConnection=" in dump) assertFalse(dump, Regex("mStartedInputConnection=(?!null)").containsMatchIn(dump))
        }
    }

    @Test
    fun pasteCutAndCopyAreRefused() {
        for (id in fields) {
            k.copyOther(label = "other", text = "pasted99")
            k.focus(id)
            k.typeKeys("ab")
            k.read { a ->
                val field = a.findViewById<EditText>(id)
                for (item in listOf(android.R.id.paste, android.R.id.pasteAsPlainText)) assertFalse(field.onTextContextMenuItem(item))
                field.setSelection(0, 2)
                for (item in listOf(android.R.id.copy, android.R.id.cut)) assertFalse(field.onTextContextMenuItem(item))
                assertFalse(field.isLongClickable)
            }
            // Paste through the input pipeline: the paste key, and Ctrl+V.
            k.instrumentation.sendKeyDownUpSync(KeyEvent.KEYCODE_PASTE)
            k.instrumentation.sendKeySync(KeyEvent(0, 0, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_V, 0, KeyEvent.META_CTRL_ON or KeyEvent.META_CTRL_LEFT_ON))
            k.instrumentation.sendKeySync(KeyEvent(0, 0, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_V, 0, KeyEvent.META_CTRL_ON or KeyEvent.META_CTRL_LEFT_ON))
            k.instrumentation.waitForIdleSync()
            assertEquals("ab", k.text(id))
            assertEquals("copy and cut left the clipboard alone", "pasted99", k.clipText())
            k.read { a -> a.findViewById<EditText>(id).text.clear() }
        }
    }

    @Test
    fun injectedKeyEventsDoNotType() {
        for (id in fields) {
            k.focus(id)
            k.typeKeys("ab")
            k.instrumentation.sendStringSync("xyz") // key events injected into the focused window
            k.shell("input text qrs") // the same from the shell, as `adb shell input` or a hardware keyboard would
            k.shell("input keyevent KEYCODE_DEL")
            k.instrumentation.waitForIdleSync()
            assertEquals("ab", k.text(id))
            k.typeKeys("c") // the field had focus all along: Keyper's keyboard still types
            assertEquals("abc", k.text(id))
            k.read { a -> a.findViewById<EditText>(id).text.clear() }
        }
    }

    @Test
    fun accessibilityCannotSetOrPasteText() {
        val automation = k.instrumentation.uiAutomation
        automation.serviceInfo = automation.serviceInfo.apply { flags = flags or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS }
        k.copyOther(label = "other", text = "pasted99")
        val setText = Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, "injected") }
        val refused = listOf(AccessibilityAction.ACTION_SET_TEXT, AccessibilityAction.ACTION_PASTE, AccessibilityAction.ACTION_CUT, AccessibilityAction.ACTION_COPY)
        for (id in fields) {
            k.focus(id)
            k.typeKeys("ab")
            // In the app's process, on the view itself.
            k.read { a ->
                val field = a.findViewById<EditText>(id)
                assertFalse(field.performAccessibilityAction(AccessibilityNodeInfo.ACTION_SET_TEXT, setText))
                assertFalse(field.performAccessibilityAction(AccessibilityNodeInfo.ACTION_PASTE, null))
            }
            // Through the system, as an accessibility service sees and drives the field.
            val name = k.context.resources.getResourceEntryName(id)
            val node = automation.rootInActiveWindow.findAccessibilityNodeInfosByViewId("${k.context.packageName}:id/$name").single()
            for (action in refused) assertFalse("$action offered", action in node.actionList)
            assertFalse(node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, setText))
            assertFalse(node.performAction(AccessibilityNodeInfo.ACTION_PASTE))
            k.instrumentation.waitForIdleSync()
            assertEquals("ab", k.text(id))
            k.read { a -> a.findViewById<EditText>(id).text.clear() }
        }
        assertNotNull(automation.rootInActiveWindow)
    }

    /** The positive side: Keyper's own keyboard does type, into whichever field has focus. */
    @Test
    fun keypersKeyboardTypesIntoBothFields() {
        k.fillInputs()
        assertEquals(EMAIL, k.text(R.id.email))
        assertEquals(SECRET, k.text(R.id.secret))
    }
}
