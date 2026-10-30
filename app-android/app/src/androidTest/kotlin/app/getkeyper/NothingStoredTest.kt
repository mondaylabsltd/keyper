package app.getkeyper

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.os.Parcel
import android.widget.EditText
import android.widget.GridLayout
import android.widget.TextView
import androidx.lifecycle.Lifecycle
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.getkeyper.core.Keyper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Claim 3, "nothing you type is stored": leaving the app wipes the sentence and the phrase, the
 * fields keep no saved state, nothing typed reaches the saved instance state, and backup is off.
 * [NoFilesTest] checks the data directories after a real derivation.
 */
@RunWith(AndroidJUnit4::class)
class NothingStoredTest {
    @get:Rule val k = KeyperRule()

    /** MainActivity's private key K (debug builds are not obfuscated). */
    private fun key(activity: MainActivity) =
        MainActivity::class.java.getDeclaredField("key").apply { isAccessible = true }.get(activity) as ByteArray?

    private fun assertWiped(keyBefore: ByteArray) {
        assertEquals("sentence kept", "", k.text(R.id.secret))
        assertTrue("phrase shown", k.phraseHidden())
        assertEquals("phrase words kept", 0, k.read { it.findViewById<GridLayout>(R.id.words).childCount })
        assertNull("key K kept", k.read(::key))
        assertTrue("key K not zeroed in memory", keyBefore.all { it == 0.toByte() })
    }

    @Test
    fun leavingTheAppWipesTheSentenceAndThePhrase() {
        k.derivePhrase()
        val keyBefore = k.read(::key)!!
        assertFalse(keyBefore.all { it == 0.toByte() })

        k.scenario.moveToState(Lifecycle.State.CREATED) // onStop: another activity covers Keyper
        k.scenario.moveToState(Lifecycle.State.RESUMED)
        assertWiped(keyBefore)
    }

    @Test
    fun pressingHomeWipesTheSentenceAndThePhrase() {
        k.derivePhrase()
        val keyBefore = k.read(::key)!!
        k.shell("input keyevent KEYCODE_HOME")
        k.waitFor("Keyper stopped", 10_000) { k.scenario.state == Lifecycle.State.CREATED }
        assertWiped(keyBefore) // read from the stopped activity, still out of sight behind the launcher
    }

    @Test
    fun theFieldsSaveNoState() = k.read { activity ->
        for (id in listOf(R.id.email, R.id.secret)) assertFalse(activity.findViewById<EditText>(id).isSaveEnabled)
    }

    /** What Android would keep for a recreation after process death: none of it is typed or derived. */
    @Test
    fun nothingTypedReachesTheSavedInstanceState() {
        val phrase = k.derivePhrase()
        val cells = k.read { a -> a.findViewById<GridLayout>(R.id.words).let { g -> (0 until g.childCount).map { (g.getChildAt(it) as TextView).text.toString() } } }
        val saved = Bundle()
        k.read { k.instrumentation.callActivityOnSaveInstanceState(it, saved) }
        val bytes = Parcel.obtain().run {
            saved.writeToParcel(this, 0)
            marshall().also { recycle() }
        }
        assertTrue("nothing was saved at all, so the check proves nothing", bytes.size > 64)
        val needles = listOf(EMAIL, SECRET, Keyper.normalizeSecret(SECRET), phrase.joinToString(" ")) + cells
        for (needle in needles) for (charset in listOf(Charsets.UTF_16LE, Charsets.UTF_8)) {
            assertFalse("saved state holds \"$needle\"", bytes.contains(needle.toByteArray(charset)))
        }
    }

    @Test
    fun backupIsOff() {
        assertEquals(0, k.context.applicationInfo.flags and ApplicationInfo.FLAG_ALLOW_BACKUP)
    }

    private fun ByteArray.contains(needle: ByteArray): Boolean =
        (0..size - needle.size).any { i -> needle.indices.all { this[i + it] == needle[it] } }
}
