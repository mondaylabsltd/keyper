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
import android.view.animation.DecelerateInterpolator
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
import app.getkeyper.core.Wipe
import java.security.MessageDigest
import kotlin.concurrent.thread
import kotlin.math.roundToInt

/** How long a copied phrase stays on the clipboard. Internal, not private: ClipboardTimeoutTest pins it. */
internal const val CLIPBOARD_MS = 60_000L

/**
 * Keyper's screen: the offline gate, both inputs on [KeyperKeyboard], the strength estimate, the
 * minute-long derivation on a worker thread, the phrase with copy and QR code; and the recovery
 * drill, a page of its own that slides in over it in the same secure window. Nothing is stored:
 * leaving the screen or going online forgets it all.
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
    private lateinit var drill: View
    private lateinit var drillForm: View
    private lateinit var drillEmail: EditText
    private lateinit var drillSecret: EditText
    private lateinit var drillReveal: TextView
    private lateinit var drillCheck: Button
    private lateinit var drillMismatch: View
    private lateinit var drillPassed: View
    // Built once per language: building an ICU formatter on every keystroke made typing feel sluggish.
    private lateinit var compact: CompactDecimalFormat
    private var uiLocales: LocaleList? = null

    /** The key K derived from the current inputs; both phrase lengths are read from it. */
    private var key: ByteArray? = null
    /** [Keyper.drillFingerprint] of the inputs that produced [key], keyed with it and wiped with it. */
    private var inputs: ByteArray? = null
    /**
     * True while the recovery drill's page is open: the user types both inputs again from memory.
     * [key] is kept for the phrase to be shown again, but the main page with it is gone meanwhile.
     */
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
        closeDrill(animate = false) // its fields are wiped, not carried over
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
        drill = findViewById(R.id.drill)
        drillForm = findViewById(R.id.drill_form)
        drillEmail = findViewById(R.id.drill_email)
        drillSecret = findViewById(R.id.drill_secret)
        drillReveal = findViewById(R.id.drill_reveal)
        drillCheck = findViewById(R.id.drill_check)
        drillMismatch = findViewById(R.id.drill_mismatch)
        drillPassed = findViewById(R.id.drill_passed)
        findViewById<View>(R.id.drill_start).setOnClickListener { openDrill() }
        findViewById<View>(R.id.drill_back).setOnClickListener { closeDrill() }
        findViewById<View>(R.id.drill_return).setOnClickListener { closeDrill() }
        drillCheck.setOnClickListener { checkDrill() }
        strengthBlock = findViewById(R.id.strength_block)
        strengthTip = findViewById(R.id.strength_tip)

        padForSystemBars(findViewById(R.id.root))
        findViewById<TextView>(R.id.footer).text = getString(R.string.footer, Keyper.domainId(domain))
        findViewById<View>(R.id.test_banner).shown = domain.contentEquals(TEST_DOMAIN)

        setUpFields()
        if (restore != null) { // before the listeners, so that restoring discards nothing
            email.setText(restore.email)
            secret.setText(restore.secret)
            if (restore.revealed) toggleReveal(secret, reveal)
            wordCount.check(restore.words)
        }
        reveal.setOnClickListener { toggleReveal(secret, reveal) }
        drillReveal.setOnClickListener { toggleReveal(drillSecret, drillReveal) }
        // Any edit of the first inputs discards the phrase, and with it any drill result.
        email.afterTextChanged { discardResult() }
        secret.afterTextChanged {
            discardResult()
            showStrength()
        }
        drillEmail.afterTextChanged { drillMismatch.shown = false }
        drillSecret.afterTextChanged { drillMismatch.shown = false }
        wordCount.setOnCheckedChangeListener { _, _ -> showPhrase() }
        generate.setOnClickListener { onGenerate() }
        findViewById<View>(R.id.copy).setOnClickListener { copyPhrase() }
        findViewById<View>(R.id.qr).setOnClickListener { showQr() }
        // "Clear all": both inputs, the phrase, any drill result, and Keyper's own copy on the clipboard.
        findViewById<View>(R.id.clear).setOnClickListener {
            email.text.clear()
            secret.text.clear()
            discardResult() // also when both were empty already, which changes no text
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
            setBusy(busy)
            radios = null
            checkOffline()
        }
    }

    override fun onStart() {
        super.onStart()
        radios = null
        handler.post(pollRadios)
    }

    /**
     * In front with window focus, the one place where Keyper can tell its own clip from a newer one:
     * a copied phrase whose time is up (the timer's clock stops in deep sleep, and a frozen or killed
     * process misses it) or whose clear could not be verified out of sight leaves the clipboard now.
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) Copied.onFocus(this)
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
        val modes = listOf(
            email to KeyperKeyboard.Mode.EMAIL, secret to KeyperKeyboard.Mode.SECRET,
            drillEmail to KeyperKeyboard.Mode.EMAIL, drillSecret to KeyperKeyboard.Mode.SECRET,
        )
        for ((field, mode) in modes) {
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
            field.setOnFocusChangeListener { _, focused -> if (focused) showKeyboard(field, mode) else if (fields.none { it.hasFocus() }) hideKeyboard() }
            field.setOnClickListener { showKeyboard(field, mode) }
        }
        for (field in listOf(secret, drillSecret)) {
            field.isSingleLine = false // after the input type, which forces a single line
            field.minLines = 3
            field.setHorizontallyScrolling(false)
            field.transformationMethod = PasswordTransformationMethod.getInstance()
        }
    }

    private val fields get() = listOf(email, secret, drillEmail, drillSecret)

    /** The field the keyboard types into: whichever has focus. */
    private val target get() = fields.firstOrNull { it.hasFocus() } ?: if (drilling) drillSecret else secret

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
        when {
            email.hasFocus() -> secret.requestFocus()
            drillEmail.hasFocus() -> drillSecret.requestFocus()
            else -> hideKeyboard()
        }
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

    /** Then leaves the drill's page; registered while it is open, under [backCloses]. */
    private val backLeavesDrill by lazy { OnBackInvokedCallback { closeDrill() } }

    // Only Android 12 and older call this: the manifest opts in to OnBackInvokedCallback, which
    // Android 13+ uses instead (backCloses), so no gesture is left unhandled.
    @SuppressLint("GestureBackNavigation")
    @Deprecated("Android 12 and older only; newer versions route Back through backCloses")
    override fun onBackPressed() {
        when {
            keyboardSlot.shown -> hideKeyboard()
            drilling -> closeDrill()
            else -> @Suppress("DEPRECATION") super.onBackPressed()
        }
    }

    override fun onStop() {
        super.onStop()
        handler.removeCallbacks(pollRadios)
        // Leaving the app forgets the secret and the phrase, and stops any derivation in flight. A
        // copied phrase stays on the clipboard until its minute is up: the wallet is where it goes.
        stopDerivation()
        discardResult(keepClipboard = true) // closes the drill's page and wipes its fields too
        secret.text.clear()
    }

    private fun onGenerate() {
        if (!offline || drilling) return // the drill's page covers Generate; a queued click does nothing
        val e = email.text.toString()
        val s = secret.text.toString()
        if (!Keyper.isValidEmail(Keyper.normalizeEmail(e))) {
            email.error = getString(R.string.error_email_invalid)
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
                TestHooks.derive?.let { return@runCatching it(email, secret) } // always null in release builds
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
                    Wipe.bytes(outcome.getOrNull())
                    return@post
                }
                outcome
                    .onSuccess {
                        key = it
                        inputs = Keyper.drillFingerprint(it, email, secret)
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
        drillCheck.isEnabled = offline && !busy
        for (field in fields) field.isEnabled = offline && !busy
        progress.shown = busy
        if (busy || !offline) {
            hideKeyboard()
            // A disabled field keeps its focus and cursor otherwise; the user picks a field again.
            for (field in fields) field.clearFocus()
        }
    }

    /**
     * Going back online forgets the secret, the phrase and a copied phrase at once, and discards
     * a derivation in flight. None of the readings needs a permission.
     */
    private fun checkOffline() {
        fun global(name: String) = Settings.Global.getInt(contentResolver, name, 0)
        val now = TestHooks.radios?.invoke() // always null in release builds
            ?: listOf(global(Settings.Global.AIRPLANE_MODE_ON) == 1, global(Settings.Global.WIFI_ON) !in WIFI_OFF_VALUES, bluetoothOn())
        val (airplane, wifi, bluetooth) = now
        if (now == radios) return
        radios = now
        offline = airplane && !wifi && !bluetooth
        if (!offline) {
            stopDerivation()
            closeDrill(animate = false) // back on the main page, which shows how to go offline
            hideKeyboard()
            secret.text.clear()
            discardResult()
            Copied.clear(this, hasWindowFocus()) // even if the phrase on screen was already discarded
        }
        offlineCard.shown = !offline
        stepAirplane.shown = !airplane
        stepWifi.shown = wifi
        stepBluetooth.shown = bluetooth
        stepBluetoothHint.shown = bluetooth
        secret.setHint(if (offline) R.string.secret_hint else R.string.secret_hint_offline)
        updateControls()
    }

    /**
     * Forgets the phrase; one that was copied leaves the clipboard with it, unless [keepClipboard].
     * Nothing is left to drill against either: the drill's page closes, and a result it showed goes.
     */
    private fun discardResult(keepClipboard: Boolean = false) {
        if (key != null && !keepClipboard) Copied.clear(this, hasWindowFocus())
        Wipe.bytes(key)
        key = null
        Wipe.bytes(inputs)
        inputs = null
        closeDrill(animate = false)
        resetDrill()
        result.shown = false
        words.removeAllViews()
        dialog?.dismiss()
        dialog = null
    }

    /**
     * Recovery drill, a page of its own over the main one: both inputs typed again from memory into
     * fields of its own, which start empty, and compared with the first ones through [inputs] at
     * once, without a second minute-long derivation. The main page and its phrase stay as they were,
     * out of sight until the drill's page closes.
     */
    private fun openDrill() {
        if (drilling || key == null || !offline || busy) return
        drilling = true
        hideKeyboard()
        email.clearFocus()
        secret.clearFocus()
        dialog?.dismiss()
        dialog = null
        resetDrill()
        if (Build.VERSION.SDK_INT >= 33) onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, backLeavesDrill)
        slide(enter = true, animate = true)
    }

    /** Back to the main page, its phrase as it was; whatever was typed in the drill is wiped. */
    private fun closeDrill(animate: Boolean = true) {
        if (!drilling) return
        drilling = false
        hideKeyboard()
        drillEmail.clearFocus()
        drillSecret.clearFocus()
        drillEmail.text.clear()
        drillSecret.text.clear()
        if (Build.VERSION.SDK_INT >= 33) onBackInvokedDispatcher.unregisterOnBackInvokedCallback(backLeavesDrill)
        slide(enter = false, animate = animate)
        if (!animate) resetDrill()
    }

    /** The drill's page as it opens: empty fields, the sentence masked, no result. */
    private fun resetDrill() {
        drillEmail.text.clear()
        drillSecret.text.clear()
        if (drillSecret.transformationMethod !is PasswordTransformationMethod) toggleReveal(drillSecret, drillReveal)
        drillForm.shown = true
        drillMismatch.shown = false
        drillPassed.shown = false
        drill.findViewById<ScrollView>(R.id.drill_scroll).scrollTo(0, 0)
    }

    private fun checkDrill() {
        checkOffline() // the radios afresh: going online closes the drill
        if (!offline || !drilling) return
        val first = inputs ?: return
        val k = key ?: return
        val typed = Keyper.drillFingerprint(k, drillEmail.text.toString(), drillSecret.text.toString())
        val match = MessageDigest.isEqual(typed, first) // in constant time
        Wipe.bytes(typed)
        if (!match) {
            drillMismatch.shown = true
            return
        }
        hideKeyboard()
        drillEmail.clearFocus()
        drillSecret.clearFocus()
        drillEmail.text.clear()
        drillSecret.text.clear()
        drillForm.shown = false
        drillPassed.shown = true
    }

    /** The drill's page slides in from the end over the main page, which moves aside a little, and back out. */
    private fun slide(enter: Boolean, animate: Boolean) {
        scroll.animate().cancel()
        drill.animate().cancel()
        if (!animate) {
            scroll.translationX = 0f
            drill.translationX = 0f
            scroll.shown = !enter
            drill.shown = enter
            return
        }
        val width = (drill.parent as View).width.toFloat()
        val toEnd = if (drill.layoutDirection == View.LAYOUT_DIRECTION_RTL) -width else width
        if (enter) {
            if (!drill.shown) drill.translationX = toEnd
            drill.shown = true
        } else {
            if (!scroll.shown) scroll.translationX = -toEnd / 4
            scroll.shown = true
        }
        val interpolator = DecelerateInterpolator(1.5f)
        scroll.animate().translationX(if (enter) -toEnd / 4 else 0f).setDuration(SLIDE_MS).setInterpolator(interpolator).start()
        drill.animate().translationX(if (enter) 0f else toEnd).setDuration(SLIDE_MS).setInterpolator(interpolator).withEndAction {
            // Only one page at a time afterwards, so that nothing on the other one can be reached.
            if (enter) {
                scroll.shown = false
                drillEmail.requestFocus()
            } else {
                drill.shown = false
                resetDrill()
            }
        }.start()
    }

    private fun wordsWanted() = if (wordCount.checkedRadioButtonId == R.id.words24) 24 else 12

    /** Null once discarded, which a click queued behind "Clear" can observe. */
    private fun phrase(): List<String>? = key?.let { Keyper.mnemonic(it, wordsWanted()) }

    private fun showPhrase() {
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

    /**
     * The first copy in each session (this process's lifetime; nothing is stored) first warns that
     * keyboards and clipboard history may keep a copy Keyper cannot erase, and offers the QR code.
     * Only an actual copy counts: after choosing the QR code instead, the next Copy warns again.
     */
    private fun copyPhrase() {
        checkOffline() // the radios afresh, not as last polled: the phrase leaves Keyper only offline
        if (!offline || phrase() == null) return
        if (Copied.warned) return copyNow()
        dialog = AlertDialog.Builder(this)
            .setTitle(R.string.copy_warning_title)
            .setMessage(R.string.copy_warning_message)
            .setPositiveButton(R.string.copy_warning_copy) { _, _ -> copyNow() }
            .setNegativeButton(R.string.copy_warning_qr) { _, _ -> showQr() }
            .create()
            .showSecure()
    }

    private fun copyNow() {
        checkOffline() // the warning may have stayed open while the radios changed
        if (!offline) return
        val words = phrase() ?: return
        val clip = ClipData.newPlainText(getString(R.string.result_title), words.joinToString(" "))
        // Keeps the phrase out of clipboard previews on Android 13+.
        clip.description.extras = PersistableBundle().apply { putBoolean("android.content.extra.IS_SENSITIVE", true) }
        Copied.copy(this, clip)
        Copied.warned = true
        Toast.makeText(this, R.string.copied, Toast.LENGTH_SHORT).show()
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

    private fun toggleReveal(field: EditText, button: TextView) {
        val hidden = field.transformationMethod is PasswordTransformationMethod
        field.transformationMethod = if (hidden) null else PasswordTransformationMethod.getInstance()
        field.setSelection(field.text.length)
        button.setText(if (hidden) R.string.hide else R.string.show)
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
        const val SLIDE_MS = 280L
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
