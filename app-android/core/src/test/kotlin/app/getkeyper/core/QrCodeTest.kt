package app.getkeyper.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigInteger

class QrCodeTest {
    /** Module-for-module against segno, for every version 1..40 and every mask (reference/make_fixtures.py). */
    @Test
    fun matchesSegno() {
        val rows = fixture("qr.tsv")
        assertEquals(40, rows.map { it[1] }.distinct().size)
        for ((text, version, mask, hex) in rows) {
            val qr = QrCode.encode(text.toByteArray(), mask.toInt())
            val size = 4 * version.toInt() + 17
            assertEquals("size of version $version", size, qr.size)
            val bits = BigInteger(hex, 16).toString(2).padStart(hex.length * 4, '0')
            for (y in 0 until size) for (x in 0 until size) {
                assertEquals("version $version mask $mask at ($x, $y)", bits[y * size + x] == '1', qr[x, y])
            }
        }
    }

    @Test
    fun longestMnemonicFits() {
        val words = List(24) { "abstract" }.joinToString(" ") // 215 bytes
        assertTrue(QrCode.encode(words).size <= 4 * 11 + 17)
    }
}
