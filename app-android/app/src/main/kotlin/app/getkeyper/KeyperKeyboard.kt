package app.getkeyper

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.os.Build
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
 * phone, and `0`/`O` or `1`/`l`/`I` cannot be confused.
 *
 * Touch works as on the iPhone: every point of the keyboard belongs to its nearest key, so a tap
 * between keys still types one; the key under the finger shows magnified above it, and types when
 * the finger lifts, so a finger that landed wrong can slide to the right key first. A second
 * finger landing types the first one's key at once, so fast two-thumb typing keeps its order.
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

    /**
     * Character keys, space and done type on lift and follow a sliding finger ([slides]); shift,
     * delete and the layer switch act the moment they go down, and [up] only ends a hold.
     */
    private class Key(val view: View, val slides: Boolean, val bubble: Boolean, val down: () -> Unit, val up: () -> Unit)

    private val keys = mutableListOf<Key>()
    private val pressed = HashMap<Int, Key>() // pointer id → the key under it
    private val bubble = Bubble()
    private val rect = Rect()
    private val noBackGesture = listOf(Rect())

    var mode = Mode.SECRET
        set(value) {
            field = value
            val email = value == Mode.EMAIL
            for (key in emailKeys) key.visibility = if (email) VISIBLE else GONE
            (spaceKey.layoutParams as LayoutParams).weight = if (email) 4f else 6f
            spaceKey.requestLayout()
            doneKey.setText(if (email) R.string.key_next else R.string.key_done)
            doneKey.contentDescription = doneKey.text
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
        isBaselineAligned = false // keys with larger text would otherwise sit lower
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

    /** TalkBack activates keys through their click listeners; touches go through [onTouchEvent]. */
    private fun View.typesOnLift(bubble: Boolean, action: () -> Unit) {
        keys += Key(this, slides = true, bubble = bubble, down = {}, up = action)
        setOnClickListener { action() }
    }

    private fun View.actsOnDown(action: () -> Unit, release: () -> Unit = {}) {
        keys += Key(this, slides = false, bubble = false, down = action, up = release)
        setOnClickListener {
            action()
            release()
        }
    }

    private fun letterKey(c: Char) = key(c.toString(), 1f, R.drawable.bg_key, mono = true).apply {
        letterKeys += this to c
        typesOnLift(bubble = true) {
            onKey(if (shift == Shift.OFF) c else c.uppercaseChar())
            if (shift == Shift.ONCE) {
                shift = Shift.OFF
                refreshShift()
            }
        }
    }

    private fun charKey(c: Char) = key(c.toString(), 1f, R.drawable.bg_key, mono = true).apply { typesOnLift(bubble = true) { onKey(c) } }

    private fun emailKey(c: Char) = charKey(c).also { emailKeys += it }

    private fun shiftKey() = iconKey(R.drawable.ic_kb_shift, 1.5f, context.getString(R.string.key_shift)).also { shiftKey = it }.apply {
        actsOnDown({
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
        actsOnDown(
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
        typesOnLift(bubble = false) { onKey(' ') }
    }

    private fun layerKey() = key("123", 1.5f, R.drawable.bg_key_special, mono = false).also { layerKey = it }.apply {
        actsOnDown({ showSymbols(symbols.visibility != VISIBLE) })
    }

    private fun doneKey() = key(context.getString(R.string.key_done), 2.5f, R.drawable.bg_key_active, mono = false).also { doneKey = it }.apply {
        setTextColor(context.getColor(R.color.on_gold))
        typesOnLift(bubble = false) { onDone() }
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

    override fun onInterceptTouchEvent(event: MotionEvent) = true

    @SuppressLint("ClickableViewAccessibility") // keys stay clickable for TalkBack, see typesOnLift
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val i = event.actionIndex
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                typePending()
                val key = keyAt(event.getX(i), event.getY(i), slidingOnly = false) ?: return true
                pressed[event.getPointerId(i)] = key
                key.view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                show(key)
                key.down()
            }
            MotionEvent.ACTION_MOVE -> for (p in 0 until event.pointerCount) {
                val id = event.getPointerId(p)
                val from = pressed[id]?.takeIf { it.slides } ?: continue
                val to = keyAt(event.getX(p), event.getY(p), slidingOnly = true) ?: continue
                if (to === from) continue
                hide(from)
                pressed[id] = to
                show(to)
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> pressed.remove(event.getPointerId(i))?.let {
                hide(it)
                it.up()
            }
            MotionEvent.ACTION_CANCEL -> cancelAll()
        }
        return true
    }

    /** The nearest key: the gaps between keys and the keyboard's edges belong to keys too. */
    private fun keyAt(x: Float, y: Float, slidingOnly: Boolean) = keys
        .filter { it.view.isShown && (it.slides || !slidingOnly) }
        .minByOrNull {
            rect.set(0, 0, it.view.width, it.view.height)
            offsetDescendantRectToMyCoords(it.view, rect)
            val dx = maxOf(rect.left - x, 0f, x - rect.right)
            val dy = maxOf(rect.top - y, 0f, y - rect.bottom)
            dx * dx + dy * dy
        }

    /** A finger landing types the key another finger still holds, as if that one had lifted. */
    private fun typePending() {
        val pending = pressed.filterValues { it.slides }
        pressed.keys -= pending.keys
        for (key in pending.values) {
            hide(key)
            key.up()
        }
    }

    private fun cancelAll() {
        val held = pressed.values.toList()
        pressed.clear()
        for (key in held) {
            hide(key)
            if (!key.slides) key.up()
        }
    }

    private fun show(key: Key) {
        key.view.isPressed = true
        if (key.bubble) bubble.show(key.view as TextView)
    }

    private fun hide(key: Key) {
        key.view.isPressed = false
        bubble.hide(key.view)
    }

    /** A finger sliding in from an edge key must not become the system's back gesture. */
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        super.onLayout(changed, l, t, r, b)
        if (!changed || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        noBackGesture[0].set(0, 0, width, height)
        systemGestureExclusionRects = noBackGesture
    }

    override fun onVisibilityAggregated(isVisible: Boolean) {
        super.onVisibilityAggregated(isVisible)
        if (!isVisible) cancelAll()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cancelAll()
        repeat.removeCallbacksAndMessages(null)
    }

    /**
     * The magnified key, shaped like the iPhone's: the key grows up into a wider head holding a
     * large copy of its character. It is drawn in the window's own overlay, so it can rise above
     * the keyboard and stays under FLAG_SECURE, which a popup window would not.
     */
    private inner class Bubble : Drawable() {
        private val path = Path()
        private val area = RectF()
        private val at = IntArray(2)
        private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = context.getColor(R.color.surface)
            setShadowLayer(dpf(6f), 0f, dpf(2f), SHADOW) // drawn from Android 9; the outline works everywhere
        }
        private val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dpf(1f)
            color = context.getColor(R.color.outline)
        }
        private val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = context.getColor(R.color.text)
            typeface = Typeface.MONOSPACE
            textAlign = Paint.Align.CENTER
            textSize = dpf(34f)
        }
        private var label = ""
        private var labelX = 0f
        private var labelY = 0f
        private var key: View? = null
        private var host: View? = null

        fun show(view: TextView) {
            val root = view.rootView
            view.getLocationInWindow(at)
            val (keyX, keyY) = at
            root.getLocationInWindow(at)
            val l = (keyX - at[0]).toFloat()
            val t = (keyY - at[1]).toFloat()
            val r = l + view.width
            val b = t + view.height
            val width = maxOf(view.width * 1.5f, view.width + dpf(16f))
            val hl = ((l + r - width) / 2).coerceAtMost(root.width - dpf(2f) - width).coerceAtLeast(dpf(2f))
            val hr = hl + width
            val neckTop = t - dpf(6f)
            val neckBottom = t + dpf(10f)
            val ht = neckTop - view.height * 1.1f
            val bend = (neckBottom - neckTop) / 2
            val rh = dpf(12f)
            val rk = dpf(8f)
            path.rewind()
            path.moveTo(l, b - rk)
            path.lineTo(l, neckBottom)
            path.cubicTo(l, neckBottom - bend, hl, neckTop + bend, hl, neckTop)
            path.lineTo(hl, ht + rh)
            path.quadTo(hl, ht, hl + rh, ht)
            path.lineTo(hr - rh, ht)
            path.quadTo(hr, ht, hr, ht + rh)
            path.lineTo(hr, neckTop)
            path.cubicTo(hr, neckTop + bend, r, neckBottom - bend, r, neckBottom)
            path.lineTo(r, b - rk)
            path.quadTo(r, b, r - rk, b)
            path.lineTo(l + rk, b)
            path.quadTo(l, b, l, b - rk)
            path.close()
            label = view.text.toString()
            labelX = (hl + hr) / 2
            labelY = (ht + neckTop) / 2 - (ink.ascent() + ink.descent()) / 2
            path.computeBounds(area, true)
            val margin = dp(10)
            setBounds(area.left.toInt() - margin, area.top.toInt() - margin, area.right.toInt() + margin, area.bottom.toInt() + margin)
            key = view
            if (host === root) {
                invalidateSelf()
            } else {
                host?.overlay?.remove(this)
                root.overlay.add(this)
                host = root
            }
        }

        fun hide(view: View) {
            if (key !== view) return
            key = null
            host?.overlay?.remove(this)
            host = null
        }

        override fun draw(canvas: Canvas) {
            canvas.drawPath(path, fill)
            canvas.drawPath(path, edge)
            canvas.drawText(label, labelX, labelY, ink)
        }

        override fun setAlpha(alpha: Int) = Unit

        override fun setColorFilter(colorFilter: ColorFilter?) = Unit

        @Deprecated("Deprecated in Java")
        override fun getOpacity() = PixelFormat.TRANSLUCENT
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).roundToInt()

    private fun dpf(value: Float) = value * resources.displayMetrics.density

    private companion object {
        const val DIGITS = "1234567890"
        const val SYMBOLS_1 = "!@#$%^&*()"
        const val SYMBOLS_2 = ".,?-_+=/"
        const val KEY_HEIGHT_DP = 46
        const val DOUBLE_TAP_MS = 400L
        const val REPEAT_DELAY_MS = 400L
        const val REPEAT_MS = 60L
        const val SHADOW = 0x40000000
    }
}
