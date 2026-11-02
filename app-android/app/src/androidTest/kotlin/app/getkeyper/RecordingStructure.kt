package app.getkeyper

import android.graphics.Matrix
import android.os.Bundle
import android.os.LocaleList
import android.view.ViewStructure
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue

/** Records exactly what the real view tree exports to an autofill service, including manual requests. */
internal class RecordingStructure : ViewStructure() {
    private val children = mutableListOf<RecordingStructure?>()
    private var value: CharSequence? = null
    private var hintValue: CharSequence? = null
    private var fillValue: AutofillValue? = null
    private var fillId: AutofillId? = null
    private val bundle = Bundle()
    fun texts(): List<String> = listOfNotNull(value?.toString(), fillValue?.takeIf { it.isText }?.textValue?.toString()) + children.filterNotNull().flatMap { it.texts() }
    override fun setText(text: CharSequence?) { value = text }
    override fun setText(text: CharSequence?, start: Int, end: Int) { value = text }
    override fun getText(): CharSequence? = value
    override fun setHint(hint: CharSequence?) { hintValue = hint }
    override fun getHint(): CharSequence? = hintValue
    override fun setAutofillValue(value: AutofillValue?) { fillValue = value }
    override fun setAutofillId(id: AutofillId) { fillId = id }
    override fun setAutofillId(parent: AutofillId, virtualId: Int) { fillId = parent }
    override fun getAutofillId(): AutofillId? = fillId
    override fun setChildCount(count: Int) { children.clear(); repeat(count) { children.add(null) } }
    override fun addChildCount(count: Int): Int = children.size.also { repeat(count) { children.add(null) } }
    override fun getChildCount(): Int = children.size
    override fun newChild(index: Int): ViewStructure = RecordingStructure().also { children[index] = it }
    override fun asyncNewChild(index: Int): ViewStructure = newChild(index)
    override fun asyncCommit() {}
    override fun getExtras(): Bundle = bundle
    override fun hasExtras(): Boolean = !bundle.isEmpty
    override fun getTextSelectionStart(): Int = 0
    override fun getTextSelectionEnd(): Int = 0
    override fun newHtmlInfoBuilder(tag: String): HtmlInfo.Builder? = null
    override fun setAccessibilityFocused(value: Boolean) {}
    override fun setActivated(value: Boolean) {}
    override fun setAlpha(value: Float) {}
    override fun setAutofillHints(hints: Array<out String>?) {}
    override fun setAutofillOptions(options: Array<out CharSequence>?) {}
    override fun setAutofillType(type: Int) {}
    override fun setCheckable(value: Boolean) {}
    override fun setChecked(value: Boolean) {}
    override fun setClassName(name: String?) {}
    override fun setClickable(value: Boolean) {}
    override fun setContentDescription(value: CharSequence?) {}
    override fun setContextClickable(value: Boolean) {}
    override fun setDataIsSensitive(value: Boolean) {}
    override fun setDimens(left: Int, top: Int, scrollX: Int, scrollY: Int, width: Int, height: Int) {}
    override fun setElevation(value: Float) {}
    override fun setEnabled(value: Boolean) {}
    override fun setFocusable(value: Boolean) {}
    override fun setFocused(value: Boolean) {}
    override fun setHtmlInfo(info: HtmlInfo) {}
    override fun setId(id: Int, pkg: String?, type: String?, entry: String?) {}
    override fun setInputType(type: Int) {}
    override fun setLocaleList(locales: LocaleList?) {}
    override fun setLongClickable(value: Boolean) {}
    override fun setOpaque(value: Boolean) {}
    override fun setSelected(value: Boolean) {}
    override fun setTextLines(offsets: IntArray?, baselines: IntArray?) {}
    override fun setTextStyle(size: Float, fg: Int, bg: Int, style: Int) {}
    override fun setTransformation(matrix: Matrix?) {}
    override fun setVisibility(value: Int) {}
    override fun setWebDomain(domain: String?) {}
}
