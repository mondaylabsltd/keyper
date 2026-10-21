package app.getkeyper.core

import kotlin.math.abs
import kotlin.math.log2
import kotlin.math.pow

/**
 * An estimate of how hard a secret is to guess, for the app's meter; not part of the protocol.
 *
 * It charges each character what a human-made sentence carries against a language model —
 * about 1.5 bits per lowercase letter of English or pinyin, not the 4.7 of a random one — a
 * little more for capitals, digits and symbols, and almost nothing for repeats and runs like
 * "abc" or "123". It cannot recognise quotes, lyrics, names or dates, so it still overrates those.
 */
class Strength private constructor(val bits: Double) {
    enum class Level { VERY_WEAK, WEAK, GOOD, STRONG }

    /** Graded by what an attacker would spend: under $1M, under $100M, under $100B, more. */
    val level: Level
        get() = crackDollars().let {
            when {
                it < 1e6 -> Level.VERY_WEAK
                it < 1e8 -> Level.WEAK
                it < 1e11 -> Level.GOOD
                else -> Level.STRONG
            }
        }

    /** Expected guesses: half the space. */
    private val guesses get() = 2.0.pow(bits - 1)

    /** Expected seconds for an attacker who has the app and the email, running [gpus] top GPUs. */
    fun crackSeconds(gpus: Int): Double = guesses / (gpus * GUESSES_PER_GPU_SECOND)

    /** Expected electricity bill of that attack in US dollars, hardware not included. */
    fun crackDollars(): Double = guesses * JOULES_PER_GUESS / 3.6e6 * USD_PER_KWH

    companion object {
        /*
         * The attacker model, deliberately generous to the attacker. One guess is an Argon2id
         * run that moves about 383 GiB through memory (1048576 blocks; 2 KiB of traffic per block
         * in the first pass, 3 KiB in the other 127). Memory bandwidth caps an RTX 4090 (1 TB/s,
         * 450 W) near 2.5 guesses per second, 180 J each, and an 8 TB/s, 1 kW data-centre GPU
         * near 20 guesses per second, 50 J each. We assume 20 per second at 40 J and power at
         * US$0.05 per kWh, so a guess costs about US$0.00000056.
         */
        const val GUESSES_PER_GPU_SECOND = 20.0
        const val JOULES_PER_GUESS = 40.0
        const val USD_PER_KWH = 0.05

        fun of(secret: String): Strength {
            // Spaces carry no information an attacker lacks: where words break follows from the words.
            val s = Keyper.normalizeSecret(secret).replace(" ", "").codePoints().toArray()
            var bits = 0.0
            var i = 0
            while (i < s.size) {
                val copy = longestEarlierMatch(s, i)
                if (copy >= 3) {
                    // Repeated text only costs a pointer back and a length.
                    bits += log2(i + 1.0) + log2(copy.toDouble())
                    i += copy
                    continue
                }
                bits += if (i > 0 && abs(s[i] - s[i - 1]) <= 1) 1.0 else classBits(s[i])
                i++
            }
            return Strength(bits)
        }

        private fun classBits(c: Int) = when (c.toChar()) {
            in 'a'..'z' -> 1.5 // a letter of an English or pinyin sentence
            in 'A'..'Z' -> 2.0 // mostly where a word starts
            in '0'..'9' -> 2.0 // years, dates and phone numbers rather than random digits
            else -> 3.0 // one of the symbols
        }

        /** Length of the longest run starting at [i] that also starts somewhere before [i] (overlap allowed). */
        private fun longestEarlierMatch(s: IntArray, i: Int): Int {
            var best = 0
            for (j in 0 until i) {
                var n = 0
                while (i + n < s.size && s[j + n] == s[i + n]) n++
                best = maxOf(best, n)
            }
            return best
        }
    }
}
