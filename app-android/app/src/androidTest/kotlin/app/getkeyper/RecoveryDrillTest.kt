package app.getkeyper

import android.os.Build
import android.os.Bundle
import android.os.Parcel
import android.os.SystemClock
import android.text.method.PasswordTransformationMethod
import android.view.View
import android.view.ViewGroup
import android.view.accessibility.AccessibilityNodeInfo
import android.view.WindowInsets
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.GridLayout
import android.widget.TextView
import androidx.lifecycle.Lifecycle
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.Espresso.pressBack
import androidx.test.espresso.matcher.ViewMatchers.withId
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.getkeyper.KeyperRule.Companion.secureWindow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Claim 5, the recovery drill: a step of its own, a page that slides in over the main screen with
 * its own title bar, both fields empty and nothing else to set; re-typing the same inputs shows a
 * success state, and "Back to the phrase" shows the same phrase again without a second derivation;
 * a different input is a mismatch that keeps the phrase hidden. The page keeps the main screen's
 * protections: FLAG_SECURE, Keyper's own keyboard, the offline gate, and a wipe on leaving the app.
 */
@RunWith(AndroidJUnit4::class)
class RecoveryDrillTest {
    @get:Rule val k = KeyperRule()

    private fun string(id: Int) = k.context.getString(id)
    private fun drillOpen() = k.onScreen(R.id.drill) && !k.onScreen(R.id.scroll) && k.read { it.findViewById<View>(R.id.drill).translationX == 0f }
    private fun drillClosed() = !k.onScreen(R.id.drill) && k.onScreen(R.id.scroll)
    private fun passed() = k.onScreen(R.id.drill_passed)

    /** Derives the phrase and opens the drill; returns the phrase that was shown. */
    private fun openDrill(words: Int = 12): List<String> {
        k.fillInputs()
        if (words == 24) k.tap(R.id.words24)
        k.tap(R.id.generate)
        val phrase = k.awaitPhrase(words)
        assertEquals(KeyperRule.expectedPhrase(words), phrase)
        k.tap(R.id.drill_start)
        k.waitFor("drill page open") { drillOpen() }
        return phrase
    }

    private fun check() = k.tap(R.id.drill_check)

    @Test
    fun theDrillIsASeparatePageThatSlidesIn() {
        k.derivePhrase()
        // Tapped on the main thread and looked at in the same pass: the page starts off to the side.
        val start = k.read { a ->
            a.findViewById<View>(R.id.drill_start).performClick()
            a.findViewById<View>(R.id.drill).translationX
        }
        assertTrue("the drill page did not slide in (started at $start)", start > 0f)
        k.waitFor("drill page open") { drillOpen() }

        assertEquals(string(R.string.drill_title), k.text(R.id.drill_title))
        assertTrue("no back control", k.onScreen(R.id.drill_back))
        assertEquals(string(R.string.drill_subtitle), k.text(R.id.drill_subtitle))
        assertEquals(string(R.string.drill_check), k.text(R.id.drill_check))
        assertTrue(k.onScreen(R.id.drill_email) && k.onScreen(R.id.drill_secret))
        // The main screen is gone, and with it the strength meter, the 12/24 selector, the language
        // switch, Generate and the phrase; none of them is part of the drill page.
        for (id in listOf(R.id.strength_block, R.id.word_count, R.id.language, R.id.generate, R.id.email, R.id.secret, R.id.result)) {
            assertFalse("${k.context.resources.getResourceEntryName(id)} on screen", k.onScreen(id))
            assertNull("${k.context.resources.getResourceEntryName(id)} on the drill page", k.read { it.findViewById<View>(R.id.drill).findViewById<View>(id) })
        }
        assertFalse(k.onScreen(R.id.drill_mismatch))
        assertFalse(passed())
    }

    @Test
    fun bothFieldsStartEmptyAndTheSentenceMasked() {
        openDrill()
        assertEquals("", k.text(R.id.drill_email))
        assertEquals("", k.text(R.id.drill_secret))
        assertTrue(k.read { it.findViewById<EditText>(R.id.drill_secret).transformationMethod is PasswordTransformationMethod })
        assertEquals(string(R.string.show), k.text(R.id.drill_reveal))
        // Show and Hide work on what is typed now.
        k.fillDrill(secret = "typed now")
        k.tap(R.id.drill_reveal)
        assertNull(k.read { it.findViewById<EditText>(R.id.drill_secret).transformationMethod })
        assertEquals(string(R.string.hide), k.text(R.id.drill_reveal))
        k.tap(R.id.drill_reveal)
        assertTrue(k.read { it.findViewById<EditText>(R.id.drill_secret).transformationMethod is PasswordTransformationMethod })
    }

    @Test
    fun theSameInputsPassAndBackToThePhraseShowsItWithoutDerivingAgain() {
        val phrase = openDrill()
        k.fillDrill()
        check()
        k.waitFor("drill passed") { passed() }
        assertEquals(string(R.string.drill_ok), k.text(R.id.drill_passed_text))
        assertTrue("still on the drill page", drillOpen())
        assertFalse("form still shown", k.onScreen(R.id.drill_form))
        assertFalse(k.onScreen(R.id.drill_mismatch))
        assertEquals("drill email kept", "", k.text(R.id.drill_email))
        assertEquals("drill sentence kept", "", k.text(R.id.drill_secret))
        assertTrue(k.phraseHidden())

        k.tap(R.id.drill_return)
        k.waitFor("back on the main page") { drillClosed() }
        assertEquals(phrase, k.awaitPhrase(12))
        assertEquals("the drill derives nothing again", 1, k.derivations)
    }

    @Test
    fun aTwentyFourWordPhraseComesBackTheSame() {
        val phrase = openDrill(words = 24)
        k.fillDrill()
        check()
        k.waitFor("drill passed") { passed() }
        k.tap(R.id.drill_return)
        k.waitFor("back on the main page") { drillClosed() }
        assertEquals(phrase, k.awaitPhrase(24))
        assertEquals(1, k.derivations)
    }

    /** Leading, trailing and repeated spaces never make a recovery fail (SPEC normalisation). */
    @Test
    fun extraSpacesStillMatch() {
        openDrill()
        k.fillDrill(secret = " " + SECRET.replace(" ", "  ") + " ")
        check()
        k.waitFor("drill passed") { passed() }
    }

    @Test
    fun aDifferentSentenceIsAMismatchThatStaysOnThePage() {
        openDrill()
        k.fillDrill(secret = SECRET.replace("midnight", "midnite"))
        check()
        k.waitFor("mismatch reported") { k.onScreen(R.id.drill_mismatch) }
        assertEquals(string(R.string.drill_mismatch), k.text(R.id.drill_mismatch))
        assertTrue("left the drill page", drillOpen())
        assertTrue(k.phraseHidden())
        assertFalse(passed())

        // Still in the drill: getting it right afterwards passes, and the message goes.
        k.fillDrill()
        assertFalse(k.onScreen(R.id.drill_mismatch))
        check()
        k.waitFor("drill passed") { passed() }
    }

    @Test
    fun aDifferentEmailIsAMismatch() {
        openDrill()
        k.fillDrill(email = "bob@example.com")
        check()
        k.waitFor("mismatch reported") { k.onScreen(R.id.drill_mismatch) }
        assertTrue(drillOpen())
        assertTrue(k.phraseHidden())
        assertFalse(passed())
    }

    @Test
    fun backLeavesTheDrillAndWipesWhatWasTyped() {
        val phrase = openDrill()
        k.fillDrill(secret = "half remembered")
        k.touch(R.id.drill_back) // in the title bar, outside any scroll view
        k.waitFor("back on the main page") { drillClosed() }
        assertEquals(phrase, k.awaitPhrase(12))
        assertEquals("", k.text(R.id.drill_email))
        assertEquals("", k.text(R.id.drill_secret))
        assertEquals(1, k.derivations)

        // The system Back closes Keyper's keyboard first, then leaves the drill page.
        k.tap(R.id.drill_start)
        k.waitFor("drill page open") { drillOpen() }
        k.focus(R.id.drill_secret)
        pressBack()
        k.waitFor("keyboard closed") { !k.shown(R.id.keyboard_slot) }
        assertTrue("Back with the keyboard open left the page", drillOpen())
        pressBack()
        k.waitFor("back on the main page") { drillClosed() }
        assertEquals(phrase, k.awaitPhrase(12))
    }

    @Test
    fun goingOnlineOnTheDrillPageWipesAndLeavesIt() {
        for (online in listOf(AIRPLANE_OFF, WIFI_ON, BLUETOOTH_ON)) {
            openDrill()
            k.fillDrill(secret = "half remembered")
            k.switchRadios(online)
            k.waitFor("drill page closed") { drillClosed() }
            assertTrue("offline card hidden", k.onScreen(R.id.offline_card))
            assertEquals("drill sentence kept", "", k.text(R.id.drill_secret))
            assertEquals("drill email kept", "", k.text(R.id.drill_email))
            assertEquals("sentence kept", "", k.text(R.id.secret))
            assertTrue(k.phraseHidden())
            assertEquals(0, k.read { it.findViewById<GridLayout>(R.id.words).childCount })
            assertFalse("Keyper's keyboard open", k.shown(R.id.keyboard_slot))
            for (id in listOf(R.id.drill_email, R.id.drill_secret, R.id.drill_check)) assertFalse(k.enabled(id))

            k.switchRadios(OFFLINE)
            assertTrue("drill page back", drillClosed())
            assertFalse(k.onScreen(R.id.drill_start))
        }
    }

    @Test
    fun theDrillPageIsSecureAndTypedOnKeypersKeyboardOnly() {
        openDrill()
        onView(withId(R.id.drill_title)).check(secureWindow)
        onView(withId(R.id.drill_secret)).check(secureWindow)
        k.read { a ->
            for (id in listOf(R.id.drill_email, R.id.drill_secret)) assertNull(a.findViewById<KeyperField>(id).onCreateInputConnection(EditorInfo()))
            if (Build.VERSION.SDK_INT >= 34) {
                assertTrue(a.findViewById<View>(R.id.drill_secret).isAccessibilityDataSensitive)
                assertTrue(a.findViewById<View>(R.id.keyboard_slot).isAccessibilityDataSensitive)
            }
        }
        val imm = k.context.getSystemService(InputMethodManager::class.java)
        for (id in listOf(R.id.drill_email, R.id.drill_secret)) {
            k.focus(id)
            SystemClock.sleep(1500) // time for a system keyboard to come up, were it going to
            assertTrue("Keyper's keyboard is open", k.shown(R.id.keyboard_slot))
            assertFalse("an IME has an input connection", k.onMain { imm.isAcceptingText })
            assertFalse("the IME is visible", k.read { it.window.decorView.rootWindowInsets.isVisible(WindowInsets.Type.ime()) })
        }
    }

    @Test
    fun leavingTheAppOnTheDrillPageWipesIt() {
        openDrill()
        k.fillDrill(secret = "half remembered")
        k.scenario.moveToState(Lifecycle.State.CREATED) // onStop: another activity covers Keyper
        k.scenario.moveToState(Lifecycle.State.RESUMED)
        assertTrue("drill page still open", drillClosed())
        assertEquals("", k.text(R.id.drill_secret))
        assertEquals("", k.text(R.id.drill_email))
        assertEquals("", k.text(R.id.secret))
        assertTrue(k.phraseHidden())
    }

    @Test
    fun editingTheFirstInputsAfterPassingLeavesNoPassedState() {
        openDrill()
        k.fillDrill()
        check()
        k.waitFor("drill passed") { passed() }
        k.tap(R.id.drill_return)
        k.waitFor("back on the main page") { drillClosed() }
        k.awaitPhrase(12)

        k.focus(R.id.email)
        k.typeKeys("x")
        assertTrue("phrase kept after an edit", k.phraseHidden())
        assertFalse("passed state kept", k.shown(R.id.drill_passed))
        assertFalse(k.onScreen(R.id.drill_start))
        assertFalse(k.onScreen(R.id.drill))

        // A new phrase opens a fresh drill: empty fields, no result.
        k.tap(R.id.generate)
        k.awaitPhrase(12)
        k.tap(R.id.drill_start)
        k.waitFor("drill page open") { drillOpen() }
        assertFalse("passed state from before", passed())
        assertTrue(k.onScreen(R.id.drill_form))
        assertEquals("", k.text(R.id.drill_email))
        assertEquals("", k.text(R.id.drill_secret))
    }

    /** Every text a view on the screen holds, whether shown or not: the views a recreation, a back step or a cache could show. */
    private fun allViewTexts(): List<String> = k.read { a ->
        val texts = mutableListOf<String>()
        fun walk(v: View) {
            if (v is TextView) texts += v.text.toString()
            v.contentDescription?.let { texts += it.toString() }
            if (v is ViewGroup) for (i in 0 until v.childCount) walk(v.getChildAt(i))
        }
        walk(a.window.decorView)
        texts
    }

    /** Every text in the accessibility tree of the window in front. */
    private fun accessibilityTexts(): List<String> {
        val texts = mutableListOf<String>()
        fun walk(node: AccessibilityNodeInfo?) {
            node ?: return
            node.text?.let { texts += it.toString() }
            node.contentDescription?.let { texts += it.toString() }
            for (i in 0 until node.childCount) walk(node.getChild(i))
        }
        walk(k.instrumentation.uiAutomation.rootInActiveWindow)
        return texts
    }

    /** The phrase's cells as the grid shows them ("01  word"), and the words themselves. */
    private fun cellTexts(phrase: List<String>) = phrase.mapIndexed { i, w -> "%02d\u00A0\u00A0%s".format(i + 1, w) }

    private fun assertNothingSensitiveLeft(why: String, phrase: List<String>, typed: String) {
        val needles = listOf(SECRET, typed, phrase.joinToString(" ")) + cellTexts(phrase)
        val tree = accessibilityTexts()
        assertTrue("$why: the accessibility tree could not be read, so the check proves nothing", tree.any { "Keyper v1" in it })
        for ((where, texts) in listOf("views" to allViewTexts(), "accessibility tree" to tree)) {
            for (needle in needles) assertTrue("$why: \"$needle\" still in the $where", texts.none { needle in it })
        }
        assertFalse("$why: drill page left open", k.shown(R.id.drill))
        assertFalse("$why: passed state left", k.shown(R.id.drill_passed))
        assertEquals("$why: words left in the grid", 0, k.read { it.findViewById<GridLayout>(R.id.words).childCount })
    }

    @Test
    fun afterGoingOnlineOrLeavingTheAppNothingSensitiveCanBeSeenAgain() {
        val typed = "half remembered sentence"
        for (way in listOf("online", "leave")) {
            val phrase = openDrill()
            k.fillDrill(secret = typed)
            k.tap(R.id.drill_reveal) // shown in clear, the worst case
            when (way) {
                "online" -> { k.switchRadios(WIFI_ON); k.waitFor("drill closed") { drillClosed() } }
                else -> { k.scenario.moveToState(Lifecycle.State.CREATED); k.scenario.moveToState(Lifecycle.State.RESUMED) }
            }
            k.waitFor("Keyper in front", 30_000) { k.read { it.hasWindowFocus() } } // slow to come back on a loaded machine
            assertNothingSensitiveLeft(way, phrase, typed)
            if (way == "online") k.switchRadios(OFFLINE)
        }
    }

    /** What Android would keep for a recreation, taken while the drill page is open: nothing typed there. */
    @Test
    fun nothingTypedInTheDrillReachesTheSavedInstanceState() {
        val phrase = openDrill()
        val typed = "half remembered sentence"
        k.fillDrill(email = "bob@example.com", secret = typed)
        val saved = Bundle()
        k.read { k.instrumentation.callActivityOnSaveInstanceState(it, saved) }
        val bytes = Parcel.obtain().run {
            saved.writeToParcel(this, 0)
            marshall().also { recycle() }
        }
        assertTrue("nothing was saved at all, so the check proves nothing", bytes.size > 64)
        for (needle in listOf("bob@example.com", typed, EMAIL, SECRET, phrase.joinToString(" ")) + cellTexts(phrase)) {
            for (charset in listOf(Charsets.UTF_16LE, Charsets.UTF_8)) {
                val n = needle.toByteArray(charset)
                assertFalse("saved state holds \"$needle\"", (0..bytes.size - n.size).any { i -> n.indices.all { bytes[i + it] == n[it] } })
            }
        }
    }

    @Test
    fun reEnteringTheDrillAlwaysStartsFresh() {
        val phrase = openDrill()
        fun assertFresh(why: String) {
            k.tap(R.id.drill_start)
            k.waitFor("$why: drill page open") { drillOpen() }
            assertEquals("$why: email", "", k.text(R.id.drill_email))
            assertEquals("$why: sentence", "", k.text(R.id.drill_secret))
            assertTrue("$why: sentence unmasked", k.read { it.findViewById<EditText>(R.id.drill_secret).transformationMethod is PasswordTransformationMethod })
            assertTrue("$why: form hidden", k.onScreen(R.id.drill_form))
            assertFalse("$why: mismatch message", k.onScreen(R.id.drill_mismatch))
            assertFalse("$why: passed state", passed())
        }
        // After a mismatch, then the back control.
        k.fillDrill(secret = "wrong guess")
        k.tap(R.id.drill_reveal)
        check()
        k.waitFor("mismatch reported") { k.onScreen(R.id.drill_mismatch) }
        k.touch(R.id.drill_back)
        k.waitFor("back on the main page") { drillClosed() }
        assertEquals("Back keeps the phrase", phrase, k.awaitPhrase(12))
        assertFresh("after a mismatch")

        // After a pass, then "Back to the phrase".
        k.fillDrill()
        check()
        k.waitFor("drill passed") { passed() }
        k.tap(R.id.drill_return)
        k.waitFor("back on the main page") { drillClosed() }
        assertFresh("after a pass")

        // After a pass, then the system Back from the success state.
        k.fillDrill()
        check()
        k.waitFor("drill passed") { passed() }
        pressBack()
        k.waitFor("back on the main page") { drillClosed() }
        assertEquals(phrase, k.awaitPhrase(12))
        assertFresh("after a pass and the system Back")
        assertEquals("nothing derived again", 1, k.derivations)
    }

    /** After a pass, an edited sentence makes a new phrase, and only a new drill can verify it: the old result is never reused. */
    @Test
    fun editingTheSentenceAfterPassingNeedsANewVerification() {
        openDrill()
        k.fillDrill()
        check()
        k.waitFor("drill passed") { passed() }
        k.tap(R.id.drill_return)
        k.waitFor("back on the main page") { drillClosed() }
        k.awaitPhrase(12)

        k.focus(R.id.secret)
        k.typeKeys(" again") // wherever the tap put the cursor
        val edited = k.text(R.id.secret)
        assertTrue(edited != SECRET)
        assertTrue("phrase kept after an edit", k.phraseHidden())
        assertFalse("passed state kept", k.shown(R.id.drill_passed))
        assertFalse(k.onScreen(R.id.drill_start))

        k.tap(R.id.generate)
        assertEquals(KeyperRule.expectedPhrase(12, secret = edited), k.awaitPhrase(12))
        k.tap(R.id.drill_start)
        k.waitFor("drill page open") { drillOpen() }
        assertFalse(passed())
        // The inputs that passed before no longer match.
        k.fillDrill()
        check()
        k.waitFor("mismatch reported") { k.onScreen(R.id.drill_mismatch) }
        assertFalse(passed())
        k.fillDrill(secret = edited)
        check()
        k.waitFor("drill passed") { passed() }
    }

    @Test
    fun generateDoesNothingWhileTheDrillIsOpen() {
        openDrill()
        k.read { it.findViewById<View>(R.id.generate).performClick() } // a click queued behind the drill's page
        SystemClock.sleep(500)
        assertEquals(1, k.derivations)
        assertTrue(drillOpen())
        assertFalse(k.shown(R.id.progress))
    }
}
