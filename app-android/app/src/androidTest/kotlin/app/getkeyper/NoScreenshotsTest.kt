package app.getkeyper

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import android.os.SystemClock
import android.view.View
import android.view.WindowManager
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.Espresso.pressBack
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.getkeyper.KeyperRule.Companion.secureWindow
import org.hamcrest.Matchers.containsString
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Claim 4, no screenshots: FLAG_SECURE is set on the main window and on each dialog's own window
 * (weak sentence, error, QR code, copy warning). Besides the flag, a system screenshot (UiAutomation's, which
 * like `adb shell screencap` blanks secure windows) shows each of them black, and a control shows
 * the same screenshot does capture the window once the test itself clears its flag.
 */
@RunWith(AndroidJUnit4::class)
class NoScreenshotsTest {
    @get:Rule val k = KeyperRule()

    private val weakTitle get() = k.context.getString(R.string.weak_title)
    private val qrCaption get() = k.context.getString(R.string.qr_caption)
    private val copyWarningTitle get() = k.context.getString(R.string.copy_warning_title)

    @Test
    fun theMainWindowIsSecure() = k.read { activity ->
        assertNotEquals(0, activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE)
        val params = activity.window.decorView.layoutParams as WindowManager.LayoutParams
        assertNotEquals(0, params.flags and WindowManager.LayoutParams.FLAG_SECURE)
    }

    @Test
    fun theWeakSentenceDialogIsSecure() {
        k.fillInputs(secret = WEAK_SECRET)
        k.tap(R.id.generate)
        onView(withText(weakTitle)).inRoot(isDialog()).check(secureWindow)
    }

    @Test
    fun theErrorDialogIsSecure() {
        k.deriveError = IllegalStateException("simulated failure")
        k.fillInputs()
        k.tap(R.id.generate)
        onView(withText(containsString("simulated failure"))).inRoot(isDialog()).check(secureWindow)
    }

    @Test
    fun theQrDialogIsSecure() {
        k.derivePhrase()
        k.tap(R.id.qr)
        onView(withText(qrCaption)).inRoot(isDialog()).check(secureWindow)
    }

    @Test
    fun theCopyWarningIsSecure() {
        k.derivePhrase()
        k.tap(R.id.copy)
        onView(withText(copyWarningTitle)).inRoot(isDialog()).check(secureWindow)
    }

    @Test
    fun screenshotsShowTheScreenAndEachDialogBlack() {
        k.derivePhrase()
        val screen = k.read { a -> Rect().also { a.window.decorView.getGlobalVisibleRect(it) } }
        val content = Rect(screen).apply { inset(width() / 6, height() / 6) }
        assertTrue("main window captured", nothingCaptured("main window", k.screenshotOrNull(), content))

        // Control: with the main window's flag cleared by the test, the same call returns an image that
        // shows it. This is also what makes a refused capture above count as "nothing captured".
        k.read { it.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
        k.waitFor("main window visible in screenshots", 5_000) { k.screenshotOrNull()?.let { !allBlack(it, content) } == true }

        // Each dialog is black on its own, over a main window that screenshots now capture.
        for ((name, open) in listOf<Pair<String, () -> Unit>>(
            "weak sentence" to { k.fillInputs(secret = WEAK_SECRET); k.tap(R.id.generate) },
            "error" to { k.deriveError = IllegalStateException("simulated failure"); k.fillInputs(); k.tap(R.id.generate) },
            "QR code" to { k.deriveError = null; k.derivePhrase(); k.tap(R.id.qr) },
            "copy warning" to { k.derivePhrase(); k.tap(R.id.copy) },
        )) {
            open()
            val matcher = when (name) {
                "weak sentence" -> withText(weakTitle)
                "error" -> withText(containsString("simulated failure"))
                "copy warning" -> withText(copyWarningTitle)
                else -> withText(qrCaption)
            }
            var bounds = Rect()
            onView(matcher).inRoot(isDialog()).check { view, missing ->
                if (missing != null) throw missing
                bounds = windowBounds(view.rootView)
            }
            SystemClock.sleep(500) // let the dialog's first frame reach the screen
            val shot = k.screenshotOrNull()
            assertTrue("$name dialog captured", nothingCaptured("$name dialog", shot, Rect(bounds).apply { inset(width() / 5, height() / 5) }))
            if (shot != null && name != "QR code") { // the QR dialog fills the screen; the others leave the main window visible above them
                val above = Rect(content.left, screen.top + screen.height() / 12, content.right, bounds.top - 10)
                if (above.height() > 20) assertFalse("$name: control region above the dialog is black", allBlack(shot, above))
            }
            pressBack() // dismiss the dialog
            k.waitFor("$name dialog closed") { k.read { it.hasWindowFocus() } }
            // A refusal must be the dialog's doing: with it gone, the same call captures the main window again.
            if (shot == null) k.waitFor("$name: capture works again without the dialog", 5_000) { k.screenshotOrNull()?.let { !allBlack(it, content) } == true }
        }
    }

    private fun windowBounds(root: View): Rect {
        val at = IntArray(2).also(root::getLocationOnScreen)
        return Rect(at[0], at[1], at[0] + root.width, at[1] + root.height)
    }

    /**
     * Nothing of [area] reached the capture: it is black, as AOSP's SurfaceFlinger draws a secure
     * layer, or the system refused the capture altogether ([shot] null), as HyperOS does while a secure
     * window is on screen. A refusal counts only next to a control: the same call returns an image as
     * soon as nothing secure is on screen (checked after each use).
     */
    private fun nothingCaptured(what: String, shot: Bitmap?, area: Rect): Boolean {
        if (shot == null) android.util.Log.i("KeyperTest", "screenshot refused by the system while the $what is on screen")
        return shot == null || allBlack(shot, area)
    }

    /** True when every sampled pixel in [area] is black, as SurfaceFlinger draws a secure layer. */
    private fun allBlack(shot: Bitmap, area: Rect): Boolean {
        val r = Rect(area)
        assertTrue("sample area $area is off the screen", r.intersect(0, 0, shot.width, shot.height) && !r.isEmpty)
        for (y in r.top until r.bottom step 8) for (x in r.left until r.right step 8) {
            val p = shot.getPixel(x, y)
            if (maxOf(Color.red(p), Color.green(p), Color.blue(p)) > 12) return false
        }
        return true
    }
}
