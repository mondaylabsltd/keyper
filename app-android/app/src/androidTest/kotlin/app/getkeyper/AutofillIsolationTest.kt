package app.getkeyper

import android.view.View
import android.widget.EditText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** An explicit autofill request includes views marked noExcludeDescendants. No secrets may leave. */
@RunWith(AndroidJUnit4::class)
class AutofillIsolationTest {
    @get:Rule val k = KeyperRule()

    @Test fun manualAutofillCannotExtractInputsOrPhrase() {
        k.derivePhrase()
        val cells = k.read { activity ->
            val grid = activity.findViewById<android.widget.GridLayout>(R.id.words)
            (0 until grid.childCount).map { (grid.getChildAt(it) as android.widget.TextView).text.toString() }
        }
        val found = k.read { activity ->
            val structure = RecordingStructure()
            activity.window.decorView.dispatchProvideAutofillStructure(structure, View.AUTOFILL_FLAG_INCLUDE_NOT_IMPORTANT_VIEWS)
            structure.texts()
        }
        for (value in listOf(EMAIL, SECRET) + cells) {
            assertFalse("manual autofill exposed a sensitive value", found.any { value in it })
        }
        // A plain editor in the same secure window is visible to autofill: FLAG_SECURE alone is insufficient.
        val control = "autofill-control-value"
        val visible = k.read { activity ->
            val parent = activity.findViewById<android.view.ViewGroup>(android.R.id.content)
            parent.addView(EditText(activity).apply { setText(control) })
            val structure = RecordingStructure()
            activity.window.decorView.dispatchProvideAutofillStructure(structure, View.AUTOFILL_FLAG_INCLUDE_NOT_IMPORTANT_VIEWS)
            structure.texts()
        }
        assertTrue("control was not captured; the test proves nothing", control in visible)
    }

    @Test fun autofillCannotInjectTextIntoAnyField() = k.read { activity ->
        for (id in listOf(R.id.email, R.id.secret, R.id.drill_email, R.id.drill_secret)) {
            val field = activity.findViewById<EditText>(id)
            field.autofill(android.view.autofill.AutofillValue.forText("injected"))
            assertEquals("", field.text.toString())
        }
    }
}
