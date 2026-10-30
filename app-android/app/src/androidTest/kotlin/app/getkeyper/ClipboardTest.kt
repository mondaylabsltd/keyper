package app.getkeyper

import android.os.SystemClock
import androidx.lifecycle.Lifecycle
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Claim 6, the clipboard: a copied phrase is cleared after 60 s and when the phone goes online,
 * but not when the user leaves Keyper (they copy, then switch to the wallet to paste); another
 * app's later clip is never cleared. BackgroundClipboardTest (module :backgroundtest) covers Keyper
 * out of sight: frozen, killed and force-stopped. ClipboardTimeoutTest (a unit test) pins the 60 s constant;
 * here most tests shorten it through [TestHooks.clipboardMs], and one waits the real minute.
 */
@RunWith(AndroidJUnit4::class)
class ClipboardTest {
    @get:Rule val k = KeyperRule()

    private fun copyPhrase(): String {
        val phrase = k.derivePhrase().joinToString(" ")
        k.copy()
        assertEquals(phrase, k.clipText())
        assertEquals(k.context.getString(R.string.result_title), k.clipLabel())
        return phrase
    }

    /**
     * A shortened lifetime that still leaves copyPhrase time to see the phrase before it goes: on a
     * heavily loaded emulator, copying and reading back took over 7 s.
     */
    private val LOADED_MS = 20_000L

    /** Sleeps until a little past the shortened lifetime of the copy made at [copiedAt]. */
    private fun sleepPast(copiedAt: Long) = SystemClock.sleep(maxOf(0, copiedAt + LOADED_MS + 1_500 - System.currentTimeMillis()))

    /** When the clip was set, by the clipboard's own wall-clock timestamp. */
    private fun copiedAt(): Long = k.onMain { k.clipboard.primaryClipDescription!!.timestamp }

    /**
     * Copies, checks the phrase is still there a little before [lifetimeMs] and gone soon after it.
     * The presence check counts only if it ran before the deadline, which a loaded machine may miss.
     */
    private fun assertClearedAfter(lifetimeMs: Long, checkBeforeMs: Long) {
        val phrase = copyPhrase()
        val copiedAt = copiedAt()
        assertTrue("clip timestamp $copiedAt is not on the wall clock", System.currentTimeMillis() - copiedAt in 0..30_000)
        SystemClock.sleep(maxOf(0, copiedAt + lifetimeMs - checkBeforeMs - System.currentTimeMillis()))
        val checkedAt = System.currentTimeMillis()
        val text = k.clipText()
        assertTrue("presence checked ${checkedAt - copiedAt} ms after the copy, too late", checkedAt - copiedAt < lifetimeMs)
        assertEquals("cleared before ${checkedAt - copiedAt} ms", phrase, text)
        k.waitFor("clipboard cleared", maxOf(1_000, lifetimeMs + 10_000 - (System.currentTimeMillis() - copiedAt))) { k.clipText() == null }
    }

    @Test
    fun theCopiedPhraseIsClearedAfterTheInterval() {
        TestHooks.clipboardMs = 5_000
        assertClearedAfter(5_000, checkBeforeMs = 1_500)
    }

    /** The real constant, end to end: still there five seconds before the minute, gone soon after it. */
    @Test(timeout = 3 * 60_000)
    fun theCopiedPhraseIsClearedAfterTheRealMinute() = assertClearedAfter(CLIPBOARD_MS, checkBeforeMs = 5_000)

    @Test
    fun goingOnlineClearsTheCopiedPhrase() {
        copyPhrase()
        k.switchRadios(WIFI_ON)
        assertNull(k.clipText())
    }

    @Test
    fun leavingTheAppDoesNotClearTheCopiedPhrase() {
        val phrase = copyPhrase()
        k.scenario.moveToState(Lifecycle.State.CREATED) // onStop
        SystemClock.sleep(1_000)
        k.scenario.moveToState(Lifecycle.State.RESUMED) // back in front, where the clipboard can be read
        assertEquals("", k.text(R.id.secret)) // leaving did wipe the sentence and the phrase...
        assertTrue(k.phraseHidden())
        assertEquals(phrase, k.clipText()) // ...but not the phrase on its way to the wallet
    }

    @Test
    fun anotherAppsLaterClipIsNeverCleared() {
        TestHooks.clipboardMs = LOADED_MS
        copyPhrase()
        val copiedAt = copiedAt()
        k.copyOther()
        sleepPast(copiedAt)
        assertEquals("groceries: milk, eggs", k.clipText())
        k.tap(R.id.clear) // discarding the phrase
        k.switchRadios(WIFI_ON) // and going online
        assertEquals("groceries: milk, eggs", k.clipText())
    }

    /** A second copy replaces the first and restarts the time: the first copy's timer clears nothing. */
    @Test
    fun aNewCopyRestartsTheTime() {
        TestHooks.clipboardMs = 4_000
        copyPhrase()
        SystemClock.sleep(2_000)
        k.tap(R.id.words24)
        k.copy()
        val second = k.clipText()!!
        assertEquals(24, second.split(' ').size)
        val copiedAt = copiedAt()
        SystemClock.sleep(maxOf(0, copiedAt + 3_000 - System.currentTimeMillis())) // past the first copy's time
        assertTrue("checked too late", System.currentTimeMillis() - copiedAt < 4_000)
        assertEquals(second, k.clipText())
        k.waitFor("second copy cleared", 15_000) { k.clipText() == null }
    }

    /** Discarding the phrase clears it at once, and nothing is left to clear a later clip at the old time. */
    @Test
    fun clearingThePhraseClearsTheClipboardAndLeavesNoTimer() {
        TestHooks.clipboardMs = LOADED_MS
        copyPhrase()
        val copiedAt = copiedAt()
        k.tap(R.id.clear)
        assertNull(k.clipText())
        k.copyOther(label = k.context.getString(R.string.result_title), text = "not a phrase")
        sleepPast(copiedAt)
        assertEquals("not a phrase", k.clipText())
    }

    /** A later clip that happens to carry Keyper's label is told apart by its timestamp. */
    @Test
    fun aLaterClipWithKeypersLabelIsNeverCleared() {
        TestHooks.clipboardMs = LOADED_MS
        copyPhrase()
        val copiedAt = copiedAt()
        SystemClock.sleep(50) // a later timestamp
        k.copyOther(label = k.context.getString(R.string.result_title), text = "not a phrase")
        sleepPast(copiedAt)
        assertEquals("not a phrase", k.clipText())
    }
}
