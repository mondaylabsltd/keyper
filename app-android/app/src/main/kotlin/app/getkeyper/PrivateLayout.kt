package app.getkeyper

import android.content.Context
import android.util.AttributeSet
import android.view.ViewStructure
import android.widget.LinearLayout

/**
 * No part of this screen belongs in an autofill service's structure. The XML importance flag
 * only prevents automatic requests: a manual request includes even "unimportant" descendants.
 */
class PrivateLayout(context: Context, attrs: AttributeSet?) : LinearLayout(context, attrs) {
    override fun dispatchProvideAutofillStructure(structure: ViewStructure, flags: Int) {
        structure.setDataIsSensitive(true)
        structure.setChildCount(0)
    }
}
