package app.getkeyper

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.SystemClock

/**
 * The phrase Keyper last copied, while it may still be on the clipboard. It is to leave the
 * clipboard after [CLIPBOARD_MS], when the phone goes online and when the phrase is discarded, but
 * not when the user leaves Keyper: they copy, then switch to the wallet to paste. Main thread only.
 *
 * The one hard rule: Keyper never erases anything but its own clip. Before any clear it reads the
 * clip's description (never the clip itself: reading another app's clip would make Android 12+
 * announce that Keyper pasted from it) and clears only when it is demonstrably Keyper's copy: the
 * marker Keyper puts in the description's extras, the same label, and the same timestamp. A clip
 * that another app copied later carries none of them, so it survives.
 *
 * That makes clearing best-effort. Since Android 10 only the app in front (with window focus) or
 * the keyboard may read even the description: out of sight Keyper reads nothing, so it cannot tell
 * its clip from a newer one, and it does not clear there (tested on Android 11 and 14: from the
 * background, the description reads as null and hasPrimaryClip() as false, whatever the clipboard
 * holds). A clear that falls due out of sight waits until Keyper is in front again ([onFocus]).
 * The phone may freeze or kill Keyper's process meanwhile, so the clip itself carries what a fresh
 * process needs to recognise it: the marker, and its own timestamp to tell whether its time is
 * up. Nothing is written to storage.
 *
 * On Android 8 and 9, which still let an app out of sight read the description, a job scheduled
 * with the system ([ClearJob]) also clears on time while Keyper is in the background, with the
 * same verification.
 */
internal object Copied {
    private val handler = Handler(Looper.getMainLooper())
    private var label: String? = null
    /** The clip's own timestamp (wall clock), read back once set: tells this copy from any later one. */
    private var stamp = 0L
    /** SystemClock.elapsedRealtime() of the copy, which keeps counting in deep sleep; the timer's clock does not. */
    private var at = 0L
    /** The clear is due (the time is up, the phone went online, the phrase was discarded) but was not verified yet. */
    private var due = false
    private var timer: Runnable? = null
    /** Looks again when an earlier process's clip, seen before its time was up, is due. */
    private var recheck: Runnable? = null

    /** The first-copy warning was shown in this process; deliberately in memory only, like everything else. */
    var warned = false

    /** [CLIPBOARD_MS]; only tests of a debug build shorten it. */
    val lifetime get() = TestHooks.clipboardMs ?: CLIPBOARD_MS

    /** In the description's extras of every clip Keyper copies, so that a fresh process still knows it. */
    private const val MARKER = "app.getkeyper.COPIED"

    /** Whether an app out of sight may read the clip's description: only before Android 10. */
    private val readableOutOfSight get() = Build.VERSION.SDK_INT < 29

    fun copy(context: Context, clip: ClipData) {
        val clipboard = context.clipboard
        forget(context)
        clip.description.extras = (clip.description.extras ?: PersistableBundle()).apply { putBoolean(MARKER, true) }
        clipboard.setPrimaryClip(clip)
        label = clip.description.label?.toString()
        stamp = clipboard.primaryClipDescription?.timestamp ?: 0 // Keyper is in front: readable
        at = SystemClock.elapsedRealtime()
        TestHooks.log("copied: timestamp readable=${stamp != 0L}")
        timer = Runnable { timer = null; clear(context) }.also { handler.postDelayed(it, lifetime) }
        if (readableOutOfSight) ClearJob.schedule(context, lifetime)
    }

    /** True once this process's copy has outlived [lifetime]. */
    private val expired get() = label != null && SystemClock.elapsedRealtime() - at >= lifetime

    /**
     * The clip should leave the clipboard now: cleared at once if it can be verified as Keyper's,
     * else kept due for [onFocus]. [focused]: Keyper has window focus, so that an empty description
     * means an empty clipboard rather than one Keyper may not read.
     */
    fun clear(context: Context, focused: Boolean = false) {
        if (label == null) {
            // This process copied nothing (or has dealt with its copy). With focus, a clip carrying
            // Keyper's marker was copied by an earlier process, frozen and killed since.
            if (focused) clearEarlierProcessClip(context, overdueOnly = false)
            return
        }
        due = true
        resolve(context, focused)
    }

    /**
     * Keyper is in front with window focus, where the description can be read: a clear that fell
     * due out of sight, or a copy whose time is up (the timer's clock stops in deep sleep, and a
     * frozen process misses it), happens now, including one copied by a process killed since.
     */
    fun onFocus(context: Context) {
        if (label == null) return clearEarlierProcessClip(context, overdueOnly = true)
        if (expired) due = true
        if (due) resolve(context, focused = true)
    }

    private fun resolve(context: Context, focused: Boolean) {
        val clipboard = context.clipboard
        val now = clipboard.primaryClipDescription
        when {
            now == null && !focused -> return TestHooks.log("clear: out of sight, unverifiable, kept due")
            now == null -> TestHooks.log("clear: clipboard already empty")
            ours(now) -> { clipboard.wipe(); TestHooks.log("clear: verified, cleared") }
            else -> TestHooks.log("clear: another clip, kept")
        }
        forget(context)
    }

    /**
     * A clip carrying Keyper's marker and label, copied by an earlier process: its timestamp cannot be
     * matched against a copy this process remembers, so it must at least not postdate now, and, for
     * a catch-up rather than a requested clear ([overdueOnly]), have outlived [lifetime] by it.
     */
    private fun clearEarlierProcessClip(context: Context, overdueOnly: Boolean) {
        val clipboard = context.clipboard
        val now = clipboard.primaryClipDescription ?: return
        if (!now.isMarked() || now.label?.toString() != context.getString(R.string.result_title)) return
        val age = System.currentTimeMillis() - now.timestamp
        if (age < 0) return
        if (overdueOnly && age < lifetime) {
            recheck?.let(handler::removeCallbacks)
            recheck = Runnable { recheck = null; clearEarlierProcessClip(context, overdueOnly = true) }.also { handler.postDelayed(it, lifetime - age) }
            return
        }
        clipboard.wipe()
        TestHooks.log("clear: verified clip of an earlier process, cleared")
    }

    private fun ours(now: ClipDescription) =
        now.isMarked() && now.label?.toString() == label && stamp != 0L && now.timestamp == stamp

    private fun ClipDescription.isMarked() = extras?.getBoolean(MARKER, false) == true

    private fun forget(context: Context) {
        timer?.let(handler::removeCallbacks)
        timer = null
        recheck?.let(handler::removeCallbacks)
        recheck = null
        label = null
        stamp = 0
        due = false
        if (readableOutOfSight) ClearJob.cancel(context)
    }

    /** From [ClearJob], out of sight (Android 8 and 9 only): verified like any other clear. */
    fun onJob(context: Context) {
        TestHooks.log("job ran: description readable=${context.clipboard.primaryClipDescription != null}")
        if (label == null) clearEarlierProcessClip(context, overdueOnly = true) else clear(context)
    }

    /** Forgets this process's copy and warning, as a fresh process would start (tests). */
    fun reset(context: Context) {
        forget(context)
        warned = false
    }

    private val Context.clipboard: ClipboardManager get() = applicationContext.getSystemService(ClipboardManager::class.java)

    private fun ClipboardManager.wipe() {
        if (Build.VERSION.SDK_INT >= 28) clearPrimaryClip() else setPrimaryClip(ClipData.newPlainText("", ""))
    }
}

/**
 * Android 8 and 9 only: the clear [Copied] schedules with the system, so that it runs on time while
 * Keyper is in the background, its process frozen or killed (not force-stopped, which cancels it).
 * Only the system may bind it (BIND_JOB_SERVICE), and a job needs no uses-permission. Not
 * persisted: the system holds it in memory only, and nothing about it is written to storage.
 */
class ClearJob : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        Copied.onJob(this)
        return false
    }

    override fun onStopJob(params: JobParameters) = false

    companion object {
        private const val ID = 1

        fun schedule(context: Context, delayMs: Long) {
            val info = JobInfo.Builder(ID, ComponentName(context, ClearJob::class.java))
                .setMinimumLatency(delayMs)
                .setOverrideDeadline(delayMs)
                .build()
            context.getSystemService(JobScheduler::class.java).schedule(info)
        }

        fun cancel(context: Context) = context.getSystemService(JobScheduler::class.java).cancel(ID)
    }
}
