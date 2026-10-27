package app.getkeyper

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.AttributeSet
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityNodeInfo.AccessibilityAction
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.view.textclassifier.TextClassifier
import android.widget.EditText

/**
 * A field typed only on [KeyperKeyboard], with Android's own cursor, draggable handle and
 * magnifier.
 *
 * Android gives a field those only when it counts as a text editor, and a text editor normally
 * hands the system keyboard an input connection. This one claims to be an editor but never hands
 * one out: the system keyboard may learn that a field has focus, never what it holds, and cannot
 * type into it. Its input type stays `TYPE_NULL`, which also keeps spell checkers away. Copy, cut,
 * paste, stylus handwriting and text set by accessibility services are refused, so text enters
 * only through Keyper's keyboard. Selecting a word never consults the system's text classifier,
 * which would otherwise receive the text around it.
 */
class KeyperField(context: Context, attrs: AttributeSet?) : EditText(context, attrs) {
    init {
        if (Build.VERSION.SDK_INT >= 33) isAutoHandwritingEnabled = false
        setTextClassifier(TextClassifier.NO_OP)
    }

    override fun onCheckIsTextEditor() = true

    override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection? = null

    /** The text menu's actions (cut, copy, paste, autofill...), whatever asks for them. */
    override fun onTextContextMenuItem(id: Int) = false

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        for (action in REFUSED) info.removeAction(action)
    }

    override fun performAccessibilityAction(action: Int, arguments: Bundle?): Boolean =
        REFUSED.none { it.id == action } && super.performAccessibilityAction(action, arguments)

    private companion object {
        val REFUSED = listOf(
            AccessibilityAction.ACTION_SET_TEXT,
            AccessibilityAction.ACTION_PASTE,
            AccessibilityAction.ACTION_CUT,
            AccessibilityAction.ACTION_COPY,
        )
    }
}
