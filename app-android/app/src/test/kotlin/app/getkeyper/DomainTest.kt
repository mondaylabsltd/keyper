package app.getkeyper

import app.getkeyper.core.Keyper
import org.junit.Assert.assertEquals
import org.junit.Test

class DomainTest {
    /** Every phrase this app has ever produced depends on the domain constant: it must never change. */
    @Test
    fun domainConstantNeverChanges() {
        val domain = DOMAIN_HEX.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        assertEquals("The domain constant changed: every user's phrase would change (SPEC.md)", "A248-7EAB", Keyper.domainId(domain))
    }
}
