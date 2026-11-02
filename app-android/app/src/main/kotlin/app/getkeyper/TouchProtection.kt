package app.getkeyper

import android.view.MotionEvent
import android.view.Window

/** Protect the whole window, including the custom keyboard and each dialog's own window. */
internal fun Window.rejectObscuredTouches() {
    val original = callback ?: return
    callback = object : Window.Callback by original {
        private var blocked = false

        override fun dispatchTouchEvent(event: MotionEvent): Boolean {
            if (event.actionMasked == MotionEvent.ACTION_DOWN) blocked = false
            val obscured = event.flags and
                (MotionEvent.FLAG_WINDOW_IS_OBSCURED or MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED) != 0
            if (obscured && !blocked) {
                // An overlay can appear halfway through a gesture. Cancel pending keys and clicks;
                // dropping just the obscured event would allow a later unobscured UP to commit them.
                val cancel = MotionEvent.obtain(event)
                cancel.action = MotionEvent.ACTION_CANCEL
                try { original.dispatchTouchEvent(cancel) } finally { cancel.recycle() }
                blocked = true
            }
            return !blocked && original.dispatchTouchEvent(event)
        }
    }
}
