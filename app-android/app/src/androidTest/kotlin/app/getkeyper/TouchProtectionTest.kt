package app.getkeyper

import android.app.AlertDialog
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.view.Window
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TouchProtectionTest {
    @get:Rule val k = KeyperRule()

    private fun tap(window: Window, target: View, flags: Int, flagsOnUp: Int = flags) {
        val at = IntArray(2).also(target::getLocationInWindow)
        val now = SystemClock.uptimeMillis()
        for ((action, eventFlags) in listOf(MotionEvent.ACTION_DOWN to flags, MotionEvent.ACTION_UP to flagsOnUp)) {
            val p = MotionEvent.PointerProperties().apply { id = 0; toolType = MotionEvent.TOOL_TYPE_FINGER }
            val c = MotionEvent.PointerCoords().apply { x = at[0] + target.width / 2f; y = at[1] + target.height / 2f; pressure = 1f; size = 1f }
            val event = MotionEvent.obtain(now, now + 10, action, 1, arrayOf(p), arrayOf(c), 0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, eventFlags)
            try { window.callback.dispatchTouchEvent(event) } finally { event.recycle() }
        }
    }

    @Test fun fullAndPartialOverlaysCannotRevealTheSecret() {
        k.focus(R.id.secret)
        for (flag in listOf(MotionEvent.FLAG_WINDOW_IS_OBSCURED, MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED)) {
            k.read { activity ->
                val reveal = activity.findViewById<View>(R.id.reveal)
                tap(activity.window, reveal, flag)
                tap(activity.window, reveal, 0, flag) // overlay arrives during a gesture
            }
            assertEquals(k.context.getString(R.string.show), k.text(R.id.reveal))
        }
        k.read { tap(it.window, it.findViewById(R.id.reveal), 0) }
        assertEquals("unobscured control did not click", k.context.getString(R.string.hide), k.text(R.id.reveal))
    }

    @Test fun dialogsHaveTheSameTouchProtection() {
        k.fillInputs(secret = WEAK_SECRET)
        k.tap(R.id.generate)
        k.read { activity ->
            val dialog = MainActivity::class.java.getDeclaredField("dialog").apply { isAccessible = true }.get(activity) as AlertDialog
            val button = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
            for (flag in listOf(MotionEvent.FLAG_WINDOW_IS_OBSCURED, MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED)) tap(dialog.window!!, button, flag)
        }
        assertEquals(0, k.derivations)
    }
}
