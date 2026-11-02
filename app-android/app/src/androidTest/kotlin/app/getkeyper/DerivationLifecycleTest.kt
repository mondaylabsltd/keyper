package app.getkeyper

import android.os.SystemClock
import android.view.View
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DerivationLifecycleTest {
    @get:Rule val k = KeyperRule()

    /** The cancelled fake ignores interruption like a completion already queued on the UI thread. */
    @Test fun anOldCompletionCannotEnableInputDuringANewerRun() {
        k.deriveMs = 1500
        k.fillInputs()
        k.tap(R.id.generate)
        k.waitFor("first run started") { k.derivations == 1 }
        k.read { it.findViewById<View>(R.id.cancel).performClick() }
        assertFalse(k.shown(R.id.progress))
        k.deriveMs = 5000
        k.read { it.findViewById<View>(R.id.generate).performClick() }
        k.waitFor("second run started") { k.derivations == 2 }
        SystemClock.sleep(2200) // first run has delivered its obsolete completion
        assertTrue("old run hid the new run's progress", k.shown(R.id.progress))
        assertFalse("old run enabled sensitive input", k.enabled(R.id.secret))
        assertFalse(k.enabled(R.id.generate))
        k.read { it.findViewById<View>(R.id.generate).performClick() }
        assertEquals("a queued click started another run", 2, k.derivations)
        k.waitFor("second run finished", 10_000) { !k.phraseHidden() }
        assertTrue(k.enabled(R.id.secret))
    }
}
