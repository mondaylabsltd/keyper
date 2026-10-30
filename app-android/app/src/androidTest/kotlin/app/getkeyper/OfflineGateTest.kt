package app.getkeyper

import android.os.SystemClock
import android.view.View
import android.widget.EditText
import android.widget.GridLayout
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Claim 2, the offline gate: going online wipes the sentence, the phrase and the copied phrase on
 * the clipboard (only while the clip is still Keyper's), and input is disabled while online. The
 * radios come from [TestHooks.radios] here; [RealRadiosTest] drives the emulator's real ones.
 */
@RunWith(AndroidJUnit4::class)
class OfflineGateTest {
    @get:Rule val k = KeyperRule(launch = false)

    private val onlineStates = mapOf("airplane mode off" to AIRPLANE_OFF, "Wi-Fi on" to WIFI_ON, "Bluetooth on" to BLUETOOTH_ON)

    private fun assertInputDisabled(why: String) {
        for (id in listOf(R.id.email, R.id.secret, R.id.generate)) assertFalse("$why: ${k.context.resources.getResourceEntryName(id)} enabled", k.enabled(id))
        assertTrue("$why: offline card hidden", k.shown(R.id.offline_card))
        assertFalse("$why: Keyper's keyboard open", k.shown(R.id.keyboard_slot))
    }

    @Test
    fun goingOnlineWipesTheSentenceThePhraseAndTheCopiedPhrase() {
        k.launch()
        for ((name, online) in onlineStates) {
            val phrase = k.derivePhrase()
            k.copy()
            assertEquals(phrase.joinToString(" "), k.clipText())

            k.switchRadios(online)
            assertEquals("$name: sentence kept", "", k.text(R.id.secret))
            assertTrue("$name: phrase shown", k.phraseHidden())
            assertEquals("$name: phrase words kept", 0, k.read { it.findViewById<GridLayout>(R.id.words).childCount })
            assertNull("$name: copied phrase left on the clipboard", k.clipText())
            assertInputDisabled(name)

            k.switchRadios(OFFLINE)
            assertTrue("$name: input enabled again offline", k.enabled(R.id.secret) && k.enabled(R.id.email))
        }
    }

    @Test
    fun goingOnlineLeavesAnotherAppsLaterClipAlone() {
        k.launch()
        k.derivePhrase()
        k.copy()
        k.copyOther()
        k.switchRadios(WIFI_ON)
        assertEquals("groceries: milk, eggs", k.clipText())
        assertEquals("", k.text(R.id.secret))
    }

    @Test
    fun inputIsDisabledWhileOnline() {
        k.radios = WIFI_ON
        k.launch()
        for ((name, online) in onlineStates) {
            k.switchRadios(online)
            assertInputDisabled(name)
            // Tapping a field opens no keyboard, and injected keys type nothing.
            k.touch(R.id.email)
            k.shell("input text abc")
            SystemClock.sleep(300)
            assertFalse("$name: keyboard opened", k.shown(R.id.keyboard_slot))
            assertEquals("", k.text(R.id.email))
            // Even with valid inputs put there by the test and Generate clicked past its disabled
            // state, nothing is derived while online.
            k.read { a ->
                a.findViewById<EditText>(R.id.email).setText(EMAIL)
                a.findViewById<EditText>(R.id.secret).setText(SECRET)
                a.findViewById<View>(R.id.generate).performClick()
            }
            SystemClock.sleep(300)
            assertEquals("$name: derived while online", 0, k.derivations)
            assertTrue(k.phraseHidden())
            k.read { a -> listOf(R.id.email, R.id.secret).forEach { a.findViewById<EditText>(it).text.clear() } }
        }
    }

    @Test
    fun goingOnlineDuringADerivationDiscardsIt() {
        k.launch()
        k.deriveMs = 3_000
        k.fillInputs()
        k.tap(R.id.generate)
        k.waitFor("derivation running") { k.shown(R.id.progress) }
        k.switchRadios(BLUETOOTH_ON)
        SystemClock.sleep(3_500) // the derivation finishes while online
        k.switchRadios(OFFLINE)
        SystemClock.sleep(500)
        assertEquals(1, k.derivations)
        assertTrue(k.phraseHidden())
        assertEquals("", k.text(R.id.secret))
    }
}
