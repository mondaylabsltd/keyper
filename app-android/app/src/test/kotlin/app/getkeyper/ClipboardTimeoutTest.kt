package app.getkeyper

import org.junit.Assert.assertEquals
import org.junit.Test

class ClipboardTimeoutTest {
    /** The website promises a copied phrase leaves the clipboard after 60 seconds. */
    @Test
    fun aCopiedPhraseStaysSixtySeconds() {
        assertEquals(60_000L, CLIPBOARD_MS)
    }
}
