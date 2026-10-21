package app.getkeyper

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import app.getkeyper.core.Keyper
import kotlin.math.roundToInt

/**
 * Keyper's own keyboard, for the email and the secret alike, so that no system keyboard ever
 * sees either. It offers exactly the protocol's characters ([Keyper.isSecretChar]) and a space,
 * in a fixed QWERTY layout with fixed sizes and a monospace face: it looks the same on every
 * phone, and `0`/`O` or `1`/`l`/`I` cannot be confused. A key acts the moment it goes down, with
 * an instant highlight and a tick, and shows no magnified preview to onlookers.
 */
@SuppressLint("ViewConstructor") // only ever created in code
class KeyperKeyboard(
    context: Context,
    private val onKey: (Char) -> Unit,
    private val onDelete: () -> Unit,
    private val onDone: () -> Unit,
) : LinearLayout(context) {
    /** The email gets `@` and `.` on the letter layer and a "next" key; the keys are otherwise the same. */
    enum class Mode { SECRET, EMAIL }

    private enum class Shift { OFF, ONCE, LOCKED }

    private var shift = Shift.OFF
    private var lastShiftTap = 0L
    private val letterKeys = mutableListOf<Pair<TextView, Char>>()
    private lateinit var shiftKey: ImageView
    private lateinit var layerKey: TextView
    private lateinit var doneKey: TextView
    private lateinit var spaceKey: TextView
    private val emailKeys = mutableListOf<View>()
    private val letters: LinearLayout
    private val symbols: LinearLayout
    private val repeat = Handler(Looper.getMainLooper())

    var mode = Mode.SECRET
        set(value) {
            field = value
            val email = value == Mode.EMAIL
            for (key in emailKeys) key.visibility = if (email) VISIBLE else GONE
            (spaceKey.layoutParams as LayoutParams).weight = if (email) 4f else 6f
            spaceKey.requestLayout()
            doneKey.setText(if (email) R.string.key_next else R.string.key_done)
        }

    init {
        orientation = VERTICAL
        setBackgroundColor(context.getColor(R.color.surface_variant))
        setPadding(dp(3), dp(6), dp(3), dp(6))
        letters = layer(
            row("qwertyuiop".map(::letterKey)),
            row(listOf(spacer(0.5f)) + "asdfghjkl".map(::letterKey) + spacer(0.5f)),
            row(listOf(shiftKey()) + "zxcvbnm".map(::letterKey) + deleteKey(1.5f)),
        )
        symbols = layer(
            row(DIGITS.map(::charKey)),
            row(SYMBOLS_1.map(::charKey)),
            row(SYMBOLS_2.map(::charKey) + deleteKey(2f)),
        )
        symbols.visibility = GONE
        addView(letters)
        addView(symbols)
        addView(row(listOf(layerKey(), emailKey('@'), spaceKey(), emailKey('.'), doneKey())))
        check((DIGITS + SYMBOLS_1 + SYMBOLS_2).toSet() - ('0'..'9').toSet() == Keyper.SECRET_SYMBOLS.toSet())
        mode = Mode.SECRET
    }

    /** Back to lowercase letters, as when the keyboard first opens on a field. */
    fun reset() {
        shift = Shift.OFF
        showSymbols(false)
        refreshShift()
    }

    private fun layer(vararg rows: View) = LinearLayout(context).apply {
        orientation = VERTICAL
        rows.forEach(::addView)
    }

    private fun row(keys: List<View>) = LinearLayout(context).apply {
        orientation = HORIZONTAL
        keys.forEach(::addView)
    }

    private fun spacer(weight: Float) = View(context).apply { layoutParams = keyParams(weight) }

    private fun keyParams(weight: Float) = LayoutParams(0, dp(KEY_HEIGHT_DP), weight).apply { setMargins(dp(3), dp(4), dp(3), dp(4)) }

    private fun key(label: String, weight: Float, background: Int, mono: Boolean, description: String = label) =
        TextView(context).apply {
            text = label
            contentDescription = description
            gravity = Gravity.CENTER
            // Fixed sizes, not sp: the keyboard must not change with the system font scale.
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, if (mono) 22f else 15f)
            typeface = if (mono) Typeface.MONOSPACE else Typeface.create("sans-serif-medium", Typeface.NORMAL)
            setTextColor(context.getColor(R.color.text))
            setBackgroundResource(background)
            layoutParams = keyParams(weight)
        }

    private fun iconKey(icon: Int, weight: Float, description: String) = ImageView(context).apply {
        setImageResource(icon)
        imageTintList = ColorStateList.valueOf(context.getColor(R.color.text))
        scaleType = ImageView.ScaleType.CENTER
        contentDescription = description
        setBackgroundResource(R.drawable.bg_key_special)
        layoutParams = keyParams(weight)
    }

    /**
     * Acts on touch-down, so a key never feels late or gets lost to a finger that slides; TalkBack's
     * activation goes through the click listener instead.
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun View.onPress(action: () -> Unit, release: () -> Unit = {}) {
        isSoundEffectsEnabled = false
        setOnClickListener { action() }
        setOnTouchListener { v, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    v.isPressed = true
                    v.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    action()
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.isPressed = false
                    release()
                }
            }
            true
        }
    }

    private fun letterKey(c: Char) = key(c.toString(), 1f, R.drawable.bg_key, mono = true).apply {
        letterKeys += this to c
        onPress({
            onKey(if (shift == Shift.OFF) c else c.uppercaseChar())
            if (shift == Shift.ONCE) {
                shift = Shift.OFF
                refreshShift()
            }
        })
    }

    private fun charKey(c: Char) = key(c.toString(), 1f, R.drawable.bg_key, mono = true).apply { onPress({ onKey(c) }) }

    private fun emailKey(c: Char) = charKey(c).also { emailKeys += it }

    private fun shiftKey() = iconKey(R.drawable.ic_kb_shift, 1.5f, context.getString(R.string.key_shift)).also { shiftKey = it }.apply {
        onPress({
            val now = SystemClock.uptimeMillis()
            shift = when {
                shift == Shift.ONCE && now - lastShiftTap < DOUBLE_TAP_MS -> Shift.LOCKED
                shift == Shift.OFF -> Shift.ONCE
                else -> Shift.OFF
            }
            lastShiftTap = now
            refreshShift()
        })
    }

    /** Holding the key keeps deleting. */
    private fun deleteKey(weight: Float) = iconKey(R.drawable.ic_kb_delete, weight, context.getString(R.string.key_delete)).apply {
        val again = object : Runnable {
            override fun run() {
                onDelete()
                repeat.postDelayed(this, REPEAT_MS)
            }
        }
        onPress(
            action = {
                onDelete()
                repeat.removeCallbacks(again)
                repeat.postDelayed(again, REPEAT_DELAY_MS)
            },
            release = { repeat.removeCallbacks(again) },
        )
    }

    private fun spaceKey() = key(context.getString(R.string.key_space), 6f, R.drawable.bg_key, mono = false).also { spaceKey = it }.apply {
        setTextColor(context.getColor(R.color.text_tertiary))
        onPress({ onKey(' ') })
    }

    private fun layerKey() = key("123", 1.5f, R.drawable.bg_key_special, mono = false).also { layerKey = it }.apply {
        onPress({ showSymbols(symbols.visibility != VISIBLE) })
    }

    private fun doneKey() = key(context.getString(R.string.key_done), 2.5f, R.drawable.bg_key_active, mono = false).also { doneKey = it }.apply {
        setTextColor(context.getColor(R.color.on_gold))
        onPress({ onDone() })
    }

    private fun showSymbols(show: Boolean) {
        symbols.visibility = if (show) VISIBLE else GONE
        letters.visibility = if (show) GONE else VISIBLE
        layerKey.text = if (show) "ABC" else "123"
    }

    private fun refreshShift() {
        for ((view, c) in letterKeys) view.text = (if (shift == Shift.OFF) c else c.uppercaseChar()).toString()
        shiftKey.setImageResource(
            when (shift) {
                Shift.OFF -> R.drawable.ic_kb_shift
                Shift.ONCE -> R.drawable.ic_kb_shift_on
                Shift.LOCKED -> R.drawable.ic_kb_caps
            },
        )
        shiftKey.setBackgroundResource(if (shift == Shift.OFF) R.drawable.bg_key_special else R.drawable.bg_key_active)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        repeat.removeCallbacksAndMessages(null)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).roundToInt()

    private companion object {
        const val DIGITS = "1234567890"
        const val SYMBOLS_1 = "!@#$%^&*()"
        const val SYMBOLS_2 = ".,?-_+=/"
        const val KEY_HEIGHT_DP = 46
        const val DOUBLE_TAP_MS = 400L
        const val REPEAT_DELAY_MS = 400L
        const val REPEAT_MS = 60L
    }
}
