package app.getkeyper.backgroundtest

import android.os.Build
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * What happens to a copied phrase in each state Keyper can be in when its time is up, with Keyper's
 * process left to the system as on a real phone: in front; in the background, cached and frozen;
 * killed; force-stopped; and in each, with another app's clip copied meanwhile, which must survive.
 *
 * The rule under test: Keyper clears only a clip it can verify as its own, and since Android 10 it
 * can read the clipboard (even the description) only in front. So from Android 10 on, a phrase whose
 * time runs out while Keyper is out of sight stays until Keyper is next in front, and is cleared
 * then, whether the process was frozen, killed or force-stopped meanwhile. On Android 8 and 9 a job
 * scheduled with the system clears it out of sight (not force-stopped). These tests assert both.
 */
@RunWith(AndroidJUnit4::class)
class BackgroundClipboardTest {
    @get:Rule val phone = Phone()

    /** Android 8 and 9: an app out of sight may still read the clip's description, so Keyper clears there too. */
    private val clearsOutOfSight = Build.VERSION.SDK_INT < 29

    private val other = "groceries: milk, eggs"

    /** Launches Keyper, derives and copies; returns the wall-clock time of the copy, as the test saw it. */
    private fun copyPhrase(lifetimeMs: Long?): Long {
        phone.clipboardLifetime(lifetimeMs)
        phone.launchKeyper()
        phone.derivePhrase()
        phone.copy()
        return System.currentTimeMillis()
    }

    private fun assertKeypersPhrase(clip: Clip?, why: String) {
        assertNotNull("$why: the clipboard is empty", clip)
        assertEquals("$why: label", phone.keyperLabel(), clip!!.label)
        assertEquals("$why: not a 12-word phrase", 12, clip.text?.split(' ')?.size)
    }

    private fun assertOthersClip(clip: Clip?, why: String) = assertEquals(why, other, clip?.text)

    private fun sleepUntil(wallClockMs: Long) = SystemClock.sleep(maxOf(0, wallClockMs - System.currentTimeMillis()))

    /**
     * Brings Keyper back in front and leaves it there a few seconds, where it can read the clipboard.
     * The assertions that follow are on the clipboard itself; Keyper's debug log only explains them.
     */
    private fun returnToKeyper(stayMs: Long = 4_000) {
        phone.launchKeyper()
        SystemClock.sleep(stayMs)
    }

    private fun log() = "\nKeyper's log:\n" + phone.keyperLog()

    /** Leaves Keyper; then, where the device has a freezer, waits for the system to freeze its process. */
    private fun leaveAndFreeze() {
        phone.leaveKeyperForOtherApps()
        if (phone.freezerEnabled()) phone.awaitFrozen()
    }

    // --- (a) Keyper in front ------------------------------------------------------------------------

    @Test(timeout = 4 * 60_000)
    fun inFront_thePhraseIsClearedAtItsTime() {
        val copied = copyPhrase(10_000)
        sleepUntil(copied + 10_000 + 5_000) // Keyper in front all along (ClipboardTest checks the phrase is there before)
        assertNull("in front, past its time" + log(), phone.readClip())
    }

    @Test(timeout = 4 * 60_000)
    fun inFront_anotherAppsLaterClipSurvives() {
        val copied = copyPhrase(10_000)
        phone.copyOtherFromBackground(text = other)
        sleepUntil(copied + 15_000)
        assertOthersClip(phone.readClip(), "another app's clip after Keyper's time was up" + log())
    }

    // --- (b) In the background ----------------------------------------------------------------------

    /**
     * Just Home: Keyper stays the "previous" app, its process alive and not frozen, so its timer does
     * fire out of sight. It cannot read the clipboard there, so it must not clear: another app's clip
     * copied meanwhile survives, and so does Keyper's own phrase, until Keyper is back in front.
     */
    @Test(timeout = 4 * 60_000)
    fun aliveInTheBackground_theTimerFiresButClearsNothingItCannotVerify() {
        val copied = copyPhrase(15_000)
        phone.home()
        sleepUntil(copied + 15_000 + 5_000)
        assertTrue("Keyper's process died", phone.pid().isNotEmpty())
        assertTrue("Keyper's process frozen", !phone.frozen())
        if (clearsOutOfSight) {
            assertNull("Android 8/9: cleared out of sight" + log(), phone.readClip())
            return
        }
        // Out of sight Keyper could not read even its own clip's description, so it left it.
        assertKeypersPhrase(phone.readClip(), "the timer fired out of sight" + log())
        phone.copyOther(text = other) // after Keyper's time, before its return
        returnToKeyper()
        assertOthersClip(phone.readClip(), "after Keyper's return" + log())
    }

    @Test(timeout = 4 * 60_000)
    fun aliveInTheBackground_anotherAppsClipCopiedBeforeTheTimerSurvives() {
        val copied = copyPhrase(15_000)
        phone.home()
        phone.copyOther(text = other) // the user copies something else in another app
        phone.home()
        sleepUntil(copied + 15_000 + 5_000)
        assertTrue("Keyper's process died", phone.pid().isNotEmpty())
        assertOthersClip(phone.readClip(), "Keyper's timer fired out of sight" + log())
        returnToKeyper()
        assertOthersClip(phone.readClip(), "after Keyper's return" + log())
    }

    @Test(timeout = 5 * 60_000)
    fun frozen_thePhraseStaysOutOfSightAndIsClearedOnReturn() {
        copyPhrase(30_000)
        phone.leaveKeyperForOtherApps()
        val clip = phone.readClip()
        assertKeypersPhrase(clip, "leaving Keyper") // the phrase stays for the wallet
        if (phone.freezerEnabled()) phone.awaitFrozen()
        sleepUntil(clip!!.timestamp + 30_000 + 10_000)
        if (clearsOutOfSight) {
            assertNull("Android 8/9: cleared out of sight", phone.readClip())
            return
        }
        if (phone.freezerEnabled()) assertTrue("Keyper's process thawed before its return", phone.frozen())
        // Out of sight Keyper reads nothing, so it cannot tell its clip from a newer one: it does not clear.
        assertKeypersPhrase(phone.readClip(), "out of sight, past its time" + log())
        returnToKeyper()
        assertNull("after Keyper's return" + log(), phone.readClip())
    }

    @Test(timeout = 5 * 60_000)
    fun frozen_anotherAppsClipSurvivesInTheBackgroundAndOnReturn() {
        copyPhrase(30_000)
        leaveAndFreeze()
        phone.copyOther(text = other)
        val copied = phone.readClip()!!.timestamp
        sleepUntil(copied + 30_000 + 10_000)
        assertOthersClip(phone.readClip(), "in the background, past Keyper's time" + log())
        returnToKeyper()
        assertOthersClip(phone.readClip(), "after Keyper's return" + log())
    }

    /** The real minute, out of sight: still there just before it, and, from Android 10 on, after it, until Keyper is back. */
    @Test(timeout = 6 * 60_000)
    fun frozen_theRealMinute() {
        copyPhrase(null)
        phone.leaveKeyperForOtherApps()
        val copied = phone.readClip()!!.timestamp
        if (phone.freezerEnabled()) phone.awaitFrozen()
        sleepUntil(copied + 50_000)
        val checkedAt = System.currentTimeMillis()
        val clip = phone.readClip()
        assertTrue("presence checked ${checkedAt - copied} ms after the copy, too late", checkedAt - copied < 60_000)
        assertKeypersPhrase(clip, "before the minute")
        sleepUntil(copied + 75_000)
        if (clearsOutOfSight) {
            assertNull("Android 8/9: cleared out of sight", phone.readClip())
            return
        }
        assertKeypersPhrase(phone.readClip(), "out of sight, past the minute" + log())
        returnToKeyper()
        assertNull("after Keyper's return" + log(), phone.readClip())
    }

    // --- (c) The process killed in the background (memory pressure, an OEM's task killer) ------------

    @Test(timeout = 5 * 60_000)
    fun killed_thePhraseIsClearedWhenKeyperIsNextInFront() {
        copyPhrase(15_000)
        phone.leaveKeyperForOtherApps()
        val copied = phone.readClip()!!.timestamp
        phone.killInBackground()
        sleepUntil(copied + 15_000 + 10_000)
        if (clearsOutOfSight) {
            assertNull("Android 8/9: the job cleared it out of sight", phone.readClip())
            return
        }
        assertKeypersPhrase(phone.readClip(), "killed, past its time" + log())
        returnToKeyper() // a fresh process, which recognises the clip by its marker, label and timestamp
        assertNull("after Keyper's return" + log(), phone.readClip())
    }

    /** Back in front before its time is up, a fresh process clears the earlier copy at its time, not before. */
    @Test(timeout = 5 * 60_000)
    fun killed_backInFrontBeforeItsTime_clearedAtItsTime() {
        copyPhrase(30_000)
        phone.leaveKeyperForOtherApps()
        val copied = phone.readClip()!!.timestamp
        phone.killInBackground()
        returnToKeyper(stayMs = 0)
        assertTrue("back in front only ${System.currentTimeMillis() - copied} ms after the copy, too late", System.currentTimeMillis() - copied < 25_000)
        sleepUntil(copied + 30_000 + 8_000) // Keyper in front all along
        assertNull("in front, past its time" + log(), phone.readClip())
        // Not before its time: the clear Keyper logged came after it.
        val cleared = Regex("""^(\d\d-\d\d \d\d:\d\d:\d\d\.\d+).*verified clip of an earlier process""", RegexOption.MULTILINE).find(phone.keyperLog())
        assertNotNull("no clear logged" + log(), cleared)
        val clearedAt = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.US)
            .parse("${java.util.Calendar.getInstance().get(java.util.Calendar.YEAR)}-${cleared!!.groupValues[1]}")!!.time
        assertTrue("cleared ${clearedAt - copied} ms after the copy, before its time", clearedAt - copied >= 30_000 - 5)
    }

    @Test(timeout = 5 * 60_000)
    fun killed_anotherAppsClipSurvives() {
        copyPhrase(15_000)
        phone.leaveKeyperForOtherApps()
        phone.killInBackground()
        phone.copyOther(text = other)
        val copied = phone.readClip()!!.timestamp
        sleepUntil(copied + 15_000 + 10_000)
        assertOthersClip(phone.readClip(), "Keyper killed, past its time" + log())
        returnToKeyper()
        assertOthersClip(phone.readClip(), "after Keyper's return" + log())
    }

    // --- (d) Force-stopped: the system cancels everything an app scheduled ---------------------------

    @Test(timeout = 5 * 60_000)
    fun forceStopped_thePhraseStaysUntilKeyperIsNextInFront() {
        copyPhrase(15_000)
        phone.leaveKeyperForOtherApps()
        val copied = phone.readClip()!!.timestamp
        phone.shell("am force-stop $KEYPER")
        sleepUntil(copied + 15_000 + 10_000)
        assertKeypersPhrase(phone.readClip(), "force-stopped, past its time" + log()) // on every version: no job survives
        returnToKeyper()
        assertNull("after Keyper's return" + log(), phone.readClip())
    }
}
