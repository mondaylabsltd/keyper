package app.getkeyper.core

import java.security.MessageDigest

/** BIP39 entropy-to-mnemonic encoding with the English wordlist. */
object Bip39 {
    /** Encodes 16, 20, 24, 28 or 32 bytes of entropy as 12, 15, 18, 21 or 24 words. */
    fun mnemonic(entropy: ByteArray): List<String> {
        require(entropy.size in 16..32 && entropy.size % 4 == 0) { "entropy must be 16..32 bytes, a multiple of 4" }
        // ENT bits followed by ENT/32 checksum bits; the checksum never exceeds one byte.
        val bits = entropy + MessageDigest.getInstance("SHA-256").digest(entropy)[0]
        val count = (entropy.size * 8 + entropy.size / 4) / 11
        return List(count) { BIP39_ENGLISH[bits.readBits(11 * it, 11)] }
    }

    private fun ByteArray.readBits(start: Int, length: Int): Int {
        var r = 0
        for (i in start until start + length) r = (r shl 1) or ((this[i / 8].toInt() ushr (7 - i % 8)) and 1)
        return r
    }
}
