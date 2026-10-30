package app.getkeyper

import android.view.View
import android.widget.TextView
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.Espresso.pressBack
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.assertion.ViewAssertions.doesNotExist
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.withId
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The QR code is the recommended way out, and the clipboard comes with a warning: the QR button is
 * first and primary, Copy second; the first copy of a session (the process's lifetime: nothing is
 * stored) warns that keyboards and clipboard history may keep a copy, and offers the QR code instead.
 * Only an actual copy counts as the first: choosing the QR code, or dismissing the warning, does not.
 */
@RunWith(AndroidJUnit4::class)
class CopyWarningTest {
    @get:Rule val k = KeyperRule()

    private fun string(id: Int) = k.context.getString(id)
    private fun warningShown() = onView(withText(string(R.string.copy_warning_title))).inRoot(isDialog())

    @Test
    fun theQrCodeComesFirstAndCopySecond() {
        k.derivePhrase()
        k.read { a ->
            val qr = a.findViewById<TextView>(R.id.qr)
            val copy = a.findViewById<TextView>(R.id.copy)
            assertTrue("QR code not before Copy", qr.left < copy.left && (qr.parent as View) === copy.parent)
            assertEquals(string(R.string.qr), qr.text.toString())
            // Primary: the generate button's colours, unlike the tonal Copy.
            assertEquals(a.findViewById<TextView>(R.id.generate).currentTextColor, qr.currentTextColor)
            assertTrue("Copy styled like the QR code", qr.currentTextColor != copy.currentTextColor)
        }
    }

    @Test
    fun theFirstCopyWarnsAndChoosingCopyCopies() {
        val phrase = k.derivePhrase().joinToString(" ")
        k.tap(R.id.copy)
        warningShown().check(matches(isDisplayed()))
        onView(withText(string(R.string.copy_warning_message))).inRoot(isDialog()).check(matches(isDisplayed()))
        assertEquals("copied before the choice", null, k.clipText())
        onView(withText(string(R.string.copy_warning_copy))).inRoot(isDialog()).perform(click())
        k.waitFor("copied") { k.clipText() == phrase }
    }

    @Test
    fun laterCopiesInTheSameSessionDoNotWarn() {
        val phrase = k.derivePhrase().joinToString(" ")
        k.copy() // the first, confirmed
        k.onMain { k.clipboard.clearPrimaryClip() }
        k.tap(R.id.copy)
        onView(withText(string(R.string.copy_warning_title))).check(doesNotExist())
        k.waitFor("copied at once") { k.clipText() == phrase }
        // Also after the phrase was discarded and derived again: the session is the process.
        k.tap(R.id.clear)
        k.derivePhrase()
        k.tap(R.id.copy)
        onView(withText(string(R.string.copy_warning_title))).check(doesNotExist())
        k.waitFor("copied at once") { k.clipText() == phrase }
    }

    @Test
    fun choosingTheQrCodeShowsItWithoutTouchingTheClipboard() {
        k.derivePhrase()
        k.copyOther()
        k.tap(R.id.copy)
        onView(withText(string(R.string.copy_warning_qr))).inRoot(isDialog()).perform(click())
        onView(withText(string(R.string.qr_caption))).inRoot(isDialog()).check(matches(isDisplayed()))
        assertEquals("groceries: milk, eggs", k.clipText())
        assertEquals("notes", k.clipLabel())
    }

    @Test
    fun choosingTheQrCodeIsNotACopySoTheNextCopyWarnsAgain() {
        val phrase = k.derivePhrase().joinToString(" ")
        k.tap(R.id.copy)
        onView(withText(string(R.string.copy_warning_qr))).inRoot(isDialog()).perform(click())
        onView(withText(string(R.string.qr_caption))).inRoot(isDialog()).perform(click()) // closes the QR code
        k.waitFor("QR code closed") { k.read { it.hasWindowFocus() } }
        assertEquals(false, k.onMain { Copied.warned })

        // Dismissing the warning is not a copy either.
        k.tap(R.id.copy)
        warningShown().check(matches(isDisplayed()))
        pressBack()
        k.waitFor("warning closed") { k.read { it.hasWindowFocus() } }
        assertEquals(null, k.clipText())

        // Copy warns again; once the phrase is actually copied, later copies do not.
        k.tap(R.id.copy)
        warningShown().check(matches(isDisplayed()))
        onView(withText(string(R.string.copy_warning_copy))).inRoot(isDialog()).perform(click())
        k.waitFor("copied") { k.clipText() == phrase }
        k.onMain { k.clipboard.clearPrimaryClip() }
        k.tap(R.id.copy)
        onView(withText(string(R.string.copy_warning_title))).check(doesNotExist())
        k.waitFor("copied at once") { k.clipText() == phrase }
    }
}
