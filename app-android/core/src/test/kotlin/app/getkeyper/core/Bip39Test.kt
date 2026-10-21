package app.getkeyper.core

import org.junit.Assert.assertEquals
import org.junit.Test
import java.security.MessageDigest

class Bip39Test {
    @Test
    fun wordlistIsTheOfficialOne() {
        val file = BIP39_ENGLISH.joinToString("\n", postfix = "\n").toByteArray()
        val sha = MessageDigest.getInstance("SHA-256").digest(file).hex()
        assertEquals("2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda", sha)
    }

    /** Trezor's reference vectors (python-mnemonic vectors.json). */
    @Test
    fun trezorVectors() {
        val rows = fixture("bip39.tsv")
        assertEquals(24, rows.size)
        for ((entropy, mnemonic) in rows) {
            assertEquals(mnemonic, Bip39.mnemonic(entropy.unhex()).joinToString(" "))
        }
    }

    @Test
    fun everyLength() {
        for (bytes in 16..32 step 4) assertEquals(bytes * 3 / 4, Bip39.mnemonic(ByteArray(bytes)).size)
    }
}
