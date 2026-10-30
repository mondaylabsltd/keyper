package app.getkeyper

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * "Clear all" on the phrase card abandons everything: both inputs (email and sentence), the phrase
 * and its key K (zeroed), a recovery drill's result, and Keyper's own copy on the clipboard, but never
 * a later clip of another app.
 */
@RunWith(AndroidJUnit4::class)
class ClearAllTest {
    @get:Rule val k = KeyperRule()

    /** MainActivity's private key K (debug builds are not obfuscated). */
    private fun key(activity: MainActivity) =
        MainActivity::class.java.getDeclaredField("key").apply { isAccessible = true }.get(activity) as ByteArray?

    @Test
    fun clearAllWipesBothInputsThePhraseTheDrillResultAndKeypersCopy() {
        val phrase = k.derivePhrase()
        assertEquals(k.context.getString(R.string.clear), k.text(R.id.clear))
        // A passed drill, back on the phrase.
        k.tap(R.id.drill_start)
        k.waitFor("drill page open") { k.onScreen(R.id.drill) && !k.onScreen(R.id.scroll) }
        k.fillDrill()
        k.tap(R.id.drill_check)
        k.waitFor("drill passed") { k.onScreen(R.id.drill_passed) }
        k.tap(R.id.drill_return)
        k.waitFor("back on the phrase") { k.onScreen(R.id.result) && !k.onScreen(R.id.drill) }
        k.copy()
        assertEquals(phrase.joinToString(" "), k.clipText())
        val keyBefore = k.read(::key)!!

        k.tap(R.id.clear)
        assertEquals("email kept", "", k.text(R.id.email))
        assertEquals("sentence kept", "", k.text(R.id.secret))
        assertTrue("phrase shown", k.phraseHidden())
        assertNull("key K kept", k.read(::key))
        assertTrue("key K not zeroed", keyBefore.all { it == 0.toByte() })
        assertFalse("passed state kept", k.shown(R.id.drill_passed))
        assertFalse(k.onScreen(R.id.drill))
        assertNull("Keyper's copy left on the clipboard", k.clipText())
    }

    @Test
    fun clearAllLeavesAnotherAppsLaterClipAlone() {
        k.derivePhrase()
        k.copy()
        k.copyOther()
        k.tap(R.id.clear)
        assertEquals("", k.text(R.id.email))
        assertEquals("groceries: milk, eggs", k.clipText())
    }
}
