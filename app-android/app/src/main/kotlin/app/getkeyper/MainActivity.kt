package app.getkeyper

import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.app.Dialog
import android.app.LocaleManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Rect
import android.graphics.Typeface
import android.icu.text.CompactDecimalFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.LocaleList
import android.os.Looper
import android.os.PersistableBundle
import android.os.SharedMemory
import android.os.SystemClock
import android.provider.Settings
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextWatcher
import android.text.method.PasswordTransformationMethod
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.ActionMode
import android.view.Gravity
import android.view.KeyEvent
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import app.getkeyper.core.Keyper
import app.getkeyper.core.QrCode
import app.getkeyper.core.Strength
import java.security.MessageDigest
import kotlin.concurrent.thread
import kotlin.math.roundToInt

/**
 * Keyper's single screen: the offline gate, both inputs on [KeyperKeyboard], the strength
 * estimate, the minute-long derivation on a worker thread, the phrase with copy and QR code,
 * and the recovery drill. Nothing is stored: leaving the screen or going online forgets it all.
 */
class MainActivity : Activity() {
    private val domain = DOMAIN_HEX.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    private val handler = Handler(Looper.getMainLooper())

    private lateinit var scroll: ScrollView
    private lateinit var keyboardSlot: View
    private lateinit var keyboard: KeyperKeyboard
    private lateinit var email: EditText
    private lateinit var secret: EditText
    private lateinit var reveal: TextView
    private lateinit var bars: ViewGroup
    private lateinit var strength: TextView
    private lateinit var crackTime: TextView
    private lateinit var wordCount: RadioGroup
    private lateinit var generate: Button
    private lateinit var progress: View
    private lateinit var progressTitle: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var progressDetail: TextView
    private lateinit var result: View
    private lateinit var words: GridLayout
    private lateinit var offlineCard: View
    private lateinit var stepAirplane: View
    private lateinit var stepWifi: View
    private lateinit var stepBluetooth: View
    private lateinit var stepBluetoothHint: View
    private lateinit var strengthBlock: View
    private lateinit var strengthTip: View
    private lateinit var drillBanner: View
    // Built once per language: building an ICU formatter on every keystroke made typing feel sluggish.
    private lateinit var compact: CompactDecimalFormat
    private var uiLocales: LocaleList? = null

    /** The key K derived from the current inputs; both phrase lengths are read from it. */
    private var key: ByteArray? = null
    /** Fingerprint of the normalised inputs that produced [key], for the recovery drill. */
    private var inputs: ByteArray? = null
    /** True while the user re-enters the inputs from memory; [key] is kept, but hidden. */
    private var drilling = false
    /** Bumped to discard the result of a derivation that is still running. */
    private var generation = 0
    private var busy = false
    /** The derivation thread; interrupting it stops Argon2 within one slice (about 0.2 s). */
    private var worker: Thread? = null
    /** Airplane mode on, Wi-Fi and Bluetooth off; nothing sensitive is typed or shown otherwise. */
    private var offline = false
    /** The radio states last shown; null forces a refresh. */
    private var radios: List<Boolean>? = null
    // Polled rather than observed: Bluetooth announces no state change through settings.
    private val pollRadios = object : Runnable {
        override fun run() {
            checkOffline()
            handler.postDelayed(this, 500)
        }
    }
    /** The QR code or the weak-secret warning; both belong to the current input. */
    private var dialog: Dialog? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) // no screenshots, blank in recents
        buildUi(restore = null)
    }

    /** What the screen shows that is not derived state, carried across an in-place rebuild. */
    private class Snapshot(val email: String, val secret: String, val revealed: Boolean, val words: Int)

    /**
     * The manifest keeps the activity alive when the language changes, so that what was typed,
     * the phrase and a running derivation survive without passing through any saved state; the
     * screen is rebuilt in place in the new language instead, without a flicker.
     */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (newConfig.locales == uiLocales) return
        val snapshot = Snapshot(email.text.toString(), secret.text.toString(), secret.transformationMethod == null, wordCount.checkedRadioButtonId)
        hideKeyboard()
        dialog?.dismiss()
        dialog = null
        buildUi(snapshot)
    }

    private fun buildUi(restore: Snapshot?) {
        setContentView(R.layout.activity_main)
        uiLocales = resources.configuration.locales
        compact = CompactDecimalFormat.getInstance(uiLocales!![0], CompactDecimalFormat.CompactStyle.LONG)
        scroll = findViewById(R.id.scroll)
        keyboardSlot = findViewById(R.id.keyboard_slot)
        email = findViewById(R.id.email)
        secret = findViewById(R.id.secret)
        reveal = findViewById(R.id.reveal)
        bars = findViewById(R.id.bars)
        strength = findViewById(R.id.strength)
        crackTime = findViewById(R.id.crack_time)
        wordCount = findViewById(R.id.word_count)
        generate = findViewById(R.id.generate)
        progress = findViewById(R.id.progress)
        progressTitle = findViewById(R.id.progress_title)
        progressBar = findViewById(R.id.progress_bar)
        progressDetail = findViewById(R.id.progress_detail)
        findViewById<View>(R.id.cancel).setOnClickListener { stopDerivation() }
        result = findViewById(R.id.result)
        words = findViewById(R.id.words)
        offlineCard = findViewById(R.id.offline_card)
        stepAirplane = findViewById(R.id.step_airplane)
        stepWifi = findViewById(R.id.step_wifi)
        stepBluetooth = findViewById(R.id.step_bluetooth)
        stepBluetoothHint = findViewById(R.id.step_bluetooth_hint)
        stepAirplane.setOnClickListener { openSettings(Settings.ACTION_AIRPLANE_MODE_SETTINGS) }
        stepWifi.setOnClickListener { openSettings(Settings.ACTION_WIFI_SETTINGS) }
        stepBluetooth.setOnClickListener { openSettings(Settings.ACTION_BLUETOOTH_SETTINGS) }
        drillBanner = findViewById(R.id.drill_banner)
        findViewById<View>(R.id.drill_start).setOnClickListener { startDrill() }
        findViewById<View>(R.id.drill_exit).setOnClickListener { endDrill(passed = false) }
        strengthBlock = findViewById(R.id.strength_block)
        strengthTip = findViewById(R.id.strength_tip)

        padForSystemBars(findViewById(R.id.root))
        findViewById<TextView>(R.id.footer).text = getString(R.string.footer, Keyper.domainId(domain))
        findViewById<View>(R.id.test_banner).shown = domain.contentEquals(TEST_DOMAIN)

        setUpFields()
        if (restore != null) { // before the listeners, so that restoring discards nothing
            email.setText(restore.email)
            secret.setText(restore.secret)
            if (restore.revealed) toggleReveal()
            wordCount.check(restore.words)
        }
        reveal.setOnClickListener { toggleReveal() }
        email.afterTextChanged { if (!drilling) discardResult() }
        secret.afterTextChanged {
            if (!drilling) discardResult()
            showStrength()
        }
        wordCount.setOnCheckedChangeListener { _, _ -> showPhrase() }
        generate.setOnClickListener { onGenerate() }
        findViewById<View>(R.id.copy).setOnClickListener { copyPhrase() }
        findViewById<View>(R.id.qr).setOnClickListener { showQr() }
        findViewById<View>(R.id.clear).setOnClickListener {
            secret.text.clear()
            discardResult() // also when the sentence was empty already, which changes no text
        }
        if (Build.VERSION.SDK_INT >= 33) {
            // The system stores the per-app language, so Keyper itself still stores nothing.
            findViewById<View>(R.id.language).apply {
                shown = true
                setOnClickListener {
                    getSystemService(LocaleManager::class.java).applicationLocales =
                        LocaleList.forLanguageTags(getString(R.string.language_switch_tag))
                }
            }
        }
        if (restore != null) {
            showStrength()
            showPhrase()
            if (drilling) {
                drillBanner.shown = true
                generate.setText(R.string.drill_check)
            }
            setBusy(busy)
            radios = null
            checkOffline()
        }
    }

    override fun onStart() {
        super.onStart()
        // The timer runs on a clock that stops in deep sleep, so a phrase copied before the phone
        // slept may have outlived its minute.
        if (Copied.expired) Copied.clear(clipboard())
        radios = null
        handler.post(pollRadios)
    }

    /**
     * Both fields are [KeyperField]s typed only on [KeyperKeyboard]. A [KeyperField] gives the
     * system keyboard no input connection, so no keyboard app can read, learn or upload what is
     * typed; the filter admits only the protocol's characters, whatever the source; and the text
     * menu, paste, drag-and-drop and hardware keys are off. Moving the cursor stays native.
     */
    private fun setUpFields() {
        keyboard = KeyperKeyboard(this, onKey = ::type, onDelete = ::delete, onDone = ::done)
        (keyboardSlot as ViewGroup).addView(keyboard)
        for ((field, mode) in listOf(email to KeyperKeyboard.Mode.EMAIL, secret to KeyperKeyboard.Mode.SECRET)) {
            field.inputType = InputType.TYPE_NULL
            field.showSoftInputOnFocus = false
            field.filters = arrayOf(InputFilter { source, start, end, _, _, _ ->
                val kept = source.subSequence(start, end).filter { Keyper.isSecretChar(it) || it == ' ' }
                if (kept.length == end - start) null else kept
            })
            field.isLongClickable = false
            field.customSelectionActionModeCallback = NO_MENU
            field.customInsertionActionModeCallback = NO_MENU
            field.setOnDragListener { _, _ -> true }
            // Hardware and injected key events never type into it either: only navigation keys pass.
            field.setOnKeyListener { _, keyCode, _ -> keyCode !in NAVIGATION_KEYS }
            field.setOnFocusChangeListener { _, focused -> if (focused) showKeyboard(field, mode) else if (!email.hasFocus() && !secret.hasFocus()) hideKeyboard() }
            field.setOnClickListener { showKeyboard(field, mode) }
        }
        secret.isSingleLine = false // after the input type, which forces a single line
        secret.minLines = 3
        secret.setHorizontallyScrolling(false)
        secret.transformationMethod = PasswordTransformationMethod.getInstance()
    }

    /** The field the keyboard types into: whichever has focus. */
    private val target get() = if (email.hasFocus()) email else secret

    private fun type(c: Char) {
        val field = target
        val (a, b) = field.selectionStart.coerceAtLeast(0) to field.selectionEnd.coerceAtLeast(0)
        field.text.replace(minOf(a, b), maxOf(a, b), c.toString())
    }

    private fun delete() {
        val field = target
        val (a, b) = field.selectionStart.coerceAtLeast(0) to field.selectionEnd.coerceAtLeast(0)
        if (a != b) field.text.delete(minOf(a, b), maxOf(a, b)) else if (a > 0) field.text.delete(a - 1, a)
    }

    /** "Next" on the email moves to the secret; "done" on the secret closes the keyboard. */
    private fun done() {
        if (email.hasFocus()) secret.requestFocus() else hideKeyboard()
    }

    private fun showKeyboard(field: EditText, mode: KeyperKeyboard.Mode) {
        if (!field.isEnabled) return
        if (keyboard.mode != mode || !keyboardSlot.shown) {
            keyboard.mode = mode
            keyboard.reset()
        }
        if (!keyboardSlot.shown) {
            keyboardSlot.shown = true
            if (Build.VERSION.SDK_INT >= 33) onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, backCloses)
        }
        field.post { field.requestRectangleOnScreen(Rect(0, 0, field.width, field.height + dp(96))) }
    }

    private fun hideKeyboard() {
        if (!keyboardSlot.shown) return
        keyboardSlot.shown = false
        if (Build.VERSION.SDK_INT >= 33) onBackInvokedDispatcher.unregisterOnBackInvokedCallback(backCloses)
    }

    /** Back closes the keyboard first (Android 13+; older versions use [onBackPressed]). */
    private val backCloses by lazy { OnBackInvokedCallback { hideKeyboard() } }

    // Only Android 12 and older call this: the manifest opts in to OnBackInvokedCallback, which
    // Android 13+ uses instead (backCloses), so no gesture is left unhandled.
    @SuppressLint("GestureBackNavigation")
    @Deprecated("Android 12 and older only; newer versions route Back through backCloses")
    override fun onBackPressed() {
        if (keyboardSlot.shown) hideKeyboard() else @Suppress("DEPRECATION") super.onBackPressed()
    }

    override fun onStop() {
        super.onStop()
        handler.removeCallbacks(pollRadios)
        // Leaving the app forgets the secret and the phrase, and stops any derivation in flight. A
        // copied phrase stays on the clipboard until its minute is up: the wallet is where it goes.
        stopDerivation()
        drilling = false
        discardResult(keepClipboard = true)
        secret.text.clear()
    }

    private fun onGenerate() {
        if (!offline) return
        val e = email.text.toString()
        val s = secret.text.toString()
        if (drilling) {
            if (fingerprint(e, s).contentEquals(inputs)) endDrill(passed = true) else secret.error = getString(R.string.drill_mismatch)
            return
        }
        if (Keyper.normalizeEmail(e).length < Keyper.MIN_EMAIL_LENGTH) {
            email.error = getString(R.string.error_email_short, Keyper.MIN_EMAIL_LENGTH)
            return
        }
        val length = Keyper.normalizeSecret(s).length
        if (length < Keyper.MIN_SECRET_LENGTH) {
            secret.error = getString(R.string.secret_too_short, length, Keyper.MIN_SECRET_LENGTH)
            return
        }
        val estimate = Strength.of(s)
        if (estimate.level >= Strength.Level.GOOD) {
            derive(e, s)
            return
        }
        // Below US$100 million of attack: a warning, never a refusal, so that a stricter
        // estimator in some later release can never lock anyone out of an existing phrase.
        dialog = AlertDialog.Builder(this)
            .setTitle(R.string.weak_title)
            .setMessage(getString(R.string.weak_message, duration(estimate.crackSeconds(gpus = 1000)), money(estimate.crackDollars())))
            .setNegativeButton(R.string.weak_edit, null)
            .setPositiveButton(R.string.weak_continue) { _, _ -> derive(e, s) }
            .create()
            .showSecure()
    }

    private fun derive(email: String, secret: String) {
        // The radios afresh, not as last polled; "Generate anyway" may come long after the check.
        checkOffline()
        if (!offline) return
        val id = ++generation
        setBusy(true)
        showProgress(done = 0, total = 1, elapsedMs = 0)
        worker = thread(name = "keyper-derive") {
            val outcome = runCatching {
                // One derivation per process, even across activity instances: two 1 GiB mappings never coexist.
                synchronized(DERIVATION) {
                    val start = SystemClock.elapsedRealtime()
                    deriveOffHeap(email, secret) { done, total ->
                        val elapsed = SystemClock.elapsedRealtime() - start
                        handler.post { if (id == generation) showProgress(done, total, elapsed) }
                    }
                }
            }
            handler.post {
                setBusy(false)
                checkOffline() // going online meanwhile bumps the generation
                if (id != generation || !offline) {
                    outcome.getOrNull()?.fill(0)
                    return@post
                }
                outcome
                    .onSuccess {
                        key = it
                        inputs = fingerprint(email, secret)
                        showPhrase()
                        scroll.post { scroll.smoothScrollTo(0, result.top) }
                    }
                    .onFailure { if (it !is InterruptedException) showError(it) }
            }
        }
    }

    /** Cancel, leaving the app, or going online: discard the result and stop computing. */
    private fun stopDerivation() {
        generation++
        worker?.interrupt()
        worker = null
    }

    private fun showProgress(done: Int, total: Int, elapsedMs: Long) {
        val fraction = done.toDouble() / total
        progressBar.progress = (fraction * progressBar.max).roundToInt()
        progressTitle.text = getString(R.string.working, (fraction * 100).toInt())
        // The time left only once a few percent give a steady rate.
        progressDetail.text = if (fraction < 0.03) {
            getString(R.string.working_detail_start)
        } else {
            getString(R.string.working_detail, duration(elapsedMs / 1000.0 * (1 / fraction - 1)))
        }
    }

    /** Argon2's 1 GiB lives in an anonymous mapping: off the Java heap, and released as soon as we are done. */
    private fun deriveOffHeap(email: String, secret: String, progress: (done: Int, total: Int) -> Unit): ByteArray =
        SharedMemory.create("keyper", Keyper.MEMORY_KIB * 1024).use { shm ->
            val memory = shm.mapReadWrite()
            try {
                Keyper.deriveKey(email, secret, domain, memory, progress)
            } finally {
                SharedMemory.unmap(memory)
            }
        }

    /**
     * The adapter's live state. Settings.Global.BLUETOOTH_ON only records whether to restore
     * Bluetooth after airplane mode, and MIUI's "half-on" keeps the radio running while its
     * switch shows off; the adapter reports both truthfully. Reading it needs no permission on
     * Android 12+; should an older system refuse, the conservative setting is used instead.
     */
    @SuppressLint("MissingPermission")
    private fun bluetoothOn(): Boolean = try {
        val state = getSystemService(BluetoothManager::class.java)?.adapter?.state ?: BluetoothAdapter.STATE_OFF
        state != BluetoothAdapter.STATE_OFF
    } catch (_: SecurityException) {
        Settings.Global.getInt(contentResolver, Settings.Global.BLUETOOTH_ON, 0) != 0
    }

    private fun openSettings(action: String) {
        try {
            startActivity(Intent(action))
        } catch (_: ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }

    private fun setBusy(busy: Boolean) {
        this.busy = busy
        updateControls()
    }

    private fun updateControls() {
        // Keeps a minute-long derivation from being cut short by the screen timeout.
        if (busy) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        generate.isEnabled = offline && !busy
        secret.isEnabled = offline && !busy
        email.isEnabled = offline && !busy
        progress.shown = busy
        if (busy || !offline) {
            hideKeyboard()
            // A disabled field keeps its focus and cursor otherwise; the user picks a field again.
            email.clearFocus()
            secret.clearFocus()
        }
    }

    /**
     * Going back online forgets the secret, the phrase and a copied phrase at once, and discards
     * a derivation in flight. None of the readings needs a permission.
     */
    private fun checkOffline() {
        fun global(name: String) = Settings.Global.getInt(contentResolver, name, 0)
        val airplane = global(Settings.Global.AIRPLANE_MODE_ON) == 1
        val wifi = global(Settings.Global.WIFI_ON) !in WIFI_OFF_VALUES
        val bluetooth = bluetoothOn()
        val now = listOf(airplane, wifi, bluetooth)
        if (now == radios) return
        radios = now
        offline = airplane && !wifi && !bluetooth
        if (!offline) {
            stopDerivation()
            drilling = false
            hideKeyboard()
            secret.text.clear()
            discardResult()
            Copied.clear(clipboard()) // even if the phrase on screen was already discarded
        }
        offlineCard.shown = !offline
        stepAirplane.shown = !airplane
        stepWifi.shown = wifi
        stepBluetooth.shown = bluetooth
        stepBluetoothHint.shown = bluetooth
        secret.setHint(if (offline) R.string.secret_hint else R.string.secret_hint_offline)
        updateControls()
    }

    /** Forgets the phrase; one that was copied leaves the clipboard with it, unless [keepClipboard]. */
    private fun discardResult(keepClipboard: Boolean = false) {
        if (key != null && !keepClipboard) Copied.clear(clipboard())
        key?.fill(0)
        key = null
        inputs?.fill(0)
        inputs = null
        drillBanner.shown = false
        generate.setText(R.string.generate)
        result.shown = false
        words.removeAllViews()
        dialog?.dismiss()
        dialog = null
    }

    /**
     * Recovery drill: hide the phrase and clear both fields; the user re-enters them from memory,
     * and the normalised inputs are compared at once, without a second minute-long derivation.
     */
    private fun startDrill() {
        drilling = true
        result.shown = false
        email.text.clear()
        secret.text.clear()
        drillBanner.shown = true
        generate.setText(R.string.drill_check)
        scroll.post { scroll.smoothScrollTo(0, 0) }
        email.requestFocus()
    }

    private fun endDrill(passed: Boolean) {
        drilling = false
        drillBanner.shown = false
        generate.setText(R.string.generate)
        if (passed) {
            hideKeyboard()
            showPhrase()
            scroll.post { scroll.smoothScrollTo(0, result.top) }
            Toast.makeText(this, R.string.drill_ok, Toast.LENGTH_LONG).show()
        } else {
            discardResult()
        }
    }

    private fun fingerprint(email: String, secret: String): ByteArray =
        MessageDigest.getInstance("SHA-256").digest((Keyper.normalizeEmail(email) + "\n" + Keyper.normalizeSecret(secret)).toByteArray(Charsets.UTF_8))

    private fun wordsWanted() = if (wordCount.checkedRadioButtonId == R.id.words24) 24 else 12

    /** Null once discarded, which a click queued behind "Clear" can observe. */
    private fun phrase(): List<String>? = key?.let { Keyper.mnemonic(it, wordsWanted()) }

    private fun showPhrase() {
        if (drilling) return // the phrase stays hidden until the drill passes, whatever is toggled meanwhile
        val list = phrase() ?: return
        words.removeAllViews()
        val cells = list.mapIndexed { i, word -> wordCell(i + 1, word).also(words::addView) }
        result.shown = true
        // Every word must be shown whole: shrink all cells alike until the widest one fits its column.
        words.post {
            val column = words.width / words.columnCount
            val room = cells.first().let { column - it.totalPaddingLeft - it.totalPaddingRight - 2 * dp(CELL_MARGIN_DP) }
            val widest = cells.maxOf { it.paint.measureText(it.text, 0, it.text.length) } / 0.96f // a little slack
            if (widest > room) {
                val size = cells.first().textSize * room / widest
                for (cell in cells) cell.setTextSize(TypedValue.COMPLEX_UNIT_PX, size)
            }
        }
    }

    private fun wordCell(number: Int, word: String) = TextView(this).apply {
        // A no-break space keeps the word on the number's line: a line break here would hide it.
        text = SpannableStringBuilder("%02d\u00A0\u00A0%s".format(number, word)).apply {
            setSpan(ForegroundColorSpan(getColor(R.color.text_tertiary)), 0, 2, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        setTextColor(getColor(R.color.text))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        fontFeatureSettings = "tnum"
        maxLines = 1
        background = getDrawable(R.drawable.bg_word)
        setPadding(dp(14), dp(11), dp(8), dp(11))
        layoutParams = GridLayout.LayoutParams(GridLayout.spec(GridLayout.UNDEFINED), GridLayout.spec(GridLayout.UNDEFINED, 1f)).apply {
            width = 0
            setMargins(dp(CELL_MARGIN_DP), dp(CELL_MARGIN_DP), dp(CELL_MARGIN_DP), dp(CELL_MARGIN_DP))
        }
    }

    private fun copyPhrase() {
        checkOffline() // the radios afresh, not as last polled: the phrase leaves Keyper only offline
        if (!offline) return
        val words = phrase() ?: return
        val clip = ClipData.newPlainText(getString(R.string.result_title), words.joinToString(" "))
        // Keeps the phrase out of clipboard previews on Android 13+.
        clip.description.extras = PersistableBundle().apply { putBoolean("android.content.extra.IS_SENSITIVE", true) }
        Copied.copy(clipboard(), clip)
        Toast.makeText(this, R.string.copied, Toast.LENGTH_SHORT).show()
    }

    /** The application-scoped clipboard, so that the timer clearing it may outlive the activity. */
    private fun clipboard() = applicationContext.getSystemService(ClipboardManager::class.java)

    /**
     * The phrase Keyper last copied, while it may still be on the clipboard. It is cleared after a
     * minute, when the phone goes online and when the phrase is discarded, but not when the user
     * leaves Keyper: they copy, then switch to the wallet to paste. Process-wide, like the timer,
     * so that a new instance of the screen still knows about it. Main thread only.
     */
    private object Copied {
        private val handler = Handler(Looper.getMainLooper())
        private var label: CharSequence? = null
        /** The clip's own timestamp, read back once set: tells this copy from a later one with the same label. */
        private var stamp = 0L
        /** SystemClock.elapsedRealtime(), which keeps counting in deep sleep; the timer's clock does not. */
        private var at = 0L
        private var timer: Runnable? = null

        val expired get() = label != null && SystemClock.elapsedRealtime() - at >= CLIPBOARD_MS

        fun copy(clipboard: ClipboardManager, clip: ClipData) {
            clipboard.setPrimaryClip(clip)
            label = clip.description.label
            stamp = clipboard.primaryClipDescription?.timestamp ?: 0
            at = SystemClock.elapsedRealtime()
            timer?.let(handler::removeCallbacks)
            timer = Runnable { clear(clipboard) }.also { handler.postDelayed(it, CLIPBOARD_MS) }
        }

        /**
         * Clears the clipboard unless it demonstrably holds something else. Only the description
         * is read: reading another app's clip would make Android 12+ announce that Keyper pasted
         * from it. Since Android 10 only the app in front may read even that; out of sight
         * Keyper cannot tell, and clears to be safe, as the timer always has.
         */
        fun clear(clipboard: ClipboardManager) {
            val ours = label ?: return
            timer?.let(handler::removeCallbacks)
            timer = null
            label = null
            val now = clipboard.primaryClipDescription
            if (now != null && (now.label?.toString() != ours.toString() || (stamp != 0L && now.timestamp != stamp))) return
            if (Build.VERSION.SDK_INT >= 28) clipboard.clearPrimaryClip() else clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    private fun showQr() {
        checkOffline()
        if (!offline) return
        val words = phrase() ?: return
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.WHITE)
            setPadding(dp(24), dp(24), dp(24), dp(24))
            addView(QrView(context, QrCode.encode(words.joinToString(" "))))
            addView(TextView(context).apply {
                setText(R.string.qr_caption)
                setTextColor(Color.DKGRAY)
                gravity = Gravity.CENTER
                setPadding(0, dp(20), 0, 0)
            })
        }
        dialog = Dialog(this, android.R.style.Theme_Material_Light_NoActionBar_Fullscreen).apply {
            setContentView(content)
            window?.attributes = window?.attributes?.apply { screenBrightness = 1f }
            content.setOnClickListener { dismiss() }
        }.showSecure()
    }

    private fun showStrength() {
        val s = secret.text.toString()
        strengthBlock.shown = Keyper.normalizeSecret(s).isNotEmpty()
        if (!strengthBlock.shown) return
        val estimate = Strength.of(s)
        // Characters exactly as the 12-character rule counts them; bits mean nothing to most people.
        val length = Keyper.normalizeSecret(s).length
        val (label, color) = when (estimate.level) {
            Strength.Level.VERY_WEAK -> R.string.level_very_weak to R.color.level_very_weak
            Strength.Level.WEAK -> R.string.level_weak to R.color.level_weak
            Strength.Level.GOOD -> R.string.level_good to R.color.level_good
            Strength.Level.STRONG -> R.string.level_strong to R.color.level_strong
        }
        val tint = ColorStateList.valueOf(getColor(color))
        for (i in 0 until bars.childCount) bars.getChildAt(i).backgroundTintList = if (i <= estimate.level.ordinal) tint else null
        if (length < Keyper.MIN_SECRET_LENGTH) {
            strength.text = getString(R.string.secret_too_short, length, Keyper.MIN_SECRET_LENGTH)
            strength.setTextColor(getColor(R.color.danger))
        } else {
            strength.text = getString(R.string.strength_summary, getString(label), length)
            strength.setTextColor(getColor(color))
        }
        crackTime.text = getString(R.string.crack_time, duration(estimate.crackSeconds(gpus = 1000)), money(estimate.crackDollars()))
        strengthTip.shown = estimate.level < Strength.Level.GOOD
    }

    private fun duration(seconds: Double): String {
        val years = seconds / (365.25 * 86400)
        fun plural(id: Int, n: Double) = resources.getQuantityString(id, n.toInt(), n.toInt())
        return when {
            seconds < 1 -> getString(R.string.under_a_second)
            seconds < 60 -> plural(R.plurals.seconds, seconds)
            seconds < 3600 -> plural(R.plurals.minutes, seconds / 60)
            seconds < 86400 -> plural(R.plurals.hours, seconds / 3600)
            years < 1 -> plural(R.plurals.days, seconds / 86400)
            years < 1000 -> plural(R.plurals.years, years)
            years < 1.38e10 -> getString(R.string.years_many, compact.format(years))
            else -> getString(R.string.beyond_universe)
        }
    }

    private fun money(dollars: Double): String = when {
        dollars < 1 -> getString(R.string.under_a_dollar)
        dollars >= 1e14 -> getString(R.string.beyond_gdp)
        else -> getString(R.string.money, compact.format(dollars))
    }

    private fun toggleReveal() {
        val hidden = secret.transformationMethod is PasswordTransformationMethod
        secret.transformationMethod = if (hidden) null else PasswordTransformationMethod.getInstance()
        secret.setSelection(secret.text.length)
        reveal.setText(if (hidden) R.string.hide else R.string.show)
    }

    private fun showError(error: Throwable) {
        val outOfMemory = error is OutOfMemoryError || error.message?.contains("ENOMEM") == true
        AlertDialog.Builder(this)
            .setMessage(if (outOfMemory) getString(R.string.error_memory) else getString(R.string.error_failed, error.toString()))
            .setPositiveButton(android.R.string.ok, null)
            .create()
            .showSecure()
    }

    /** A dialog is a window of its own: without FLAG_SECURE it could be captured over the secure screen. */
    private fun <T : Dialog> T.showSecure(): T = apply {
        window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE) // before show(), so no frame escapes
        show()
    }

    /** Since Android 15 the window is always edge to edge; keep content clear of the bars, cutout and keyboard. */
    private fun padForSystemBars(root: View) {
        root.setOnApplyWindowInsetsListener { v, insets ->
            if (Build.VERSION.SDK_INT >= 30) {
                val i = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout() or WindowInsets.Type.ime())
                v.setPadding(i.left, i.top, i.right, i.bottom)
            } else {
                @Suppress("DEPRECATION")
                v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).roundToInt()

    private var View.shown: Boolean
        get() = visibility == View.VISIBLE
        set(value) {
            visibility = if (value) View.VISIBLE else View.GONE
        }

    private inline fun EditText.afterTextChanged(crossinline action: () -> Unit) = addTextChangedListener(object : TextWatcher {
        override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
        override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
        override fun afterTextChanged(s: Editable?) = action()
    })

    private companion object {
        /** SPEC.md's test domain constant; a build carrying it gets a warning banner. */
        val TEST_DOMAIN = ByteArray(32) { it.toByte() }
        val DERIVATION = Any()
        const val CELL_MARGIN_DP = 3
        const val CLIPBOARD_MS = 60_000L
        val NO_MENU = object : ActionMode.Callback {
            override fun onCreateActionMode(mode: ActionMode, menu: Menu) = false
            override fun onPrepareActionMode(mode: ActionMode, menu: Menu) = false
            override fun onActionItemClicked(mode: ActionMode, item: MenuItem) = false
            override fun onDestroyActionMode(mode: ActionMode) {}
        }
        val NAVIGATION_KEYS = setOf(
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE, KeyEvent.KEYCODE_TAB, KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_DPAD_CENTER,
        )
        /** Settings.Global.WIFI_ON: 0 disabled, 3 disabled by airplane mode; 1 and 2 mean on. */
        val WIFI_OFF_VALUES = setOf(0, 3)
    }
}
