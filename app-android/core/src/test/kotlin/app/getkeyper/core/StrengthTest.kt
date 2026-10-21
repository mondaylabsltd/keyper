package app.getkeyper.core

import app.getkeyper.core.Strength.Level
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StrengthTest {
    private fun bits(s: String) = Strength.of(s).bits
    private fun level(s: String) = Strength.of(s).level

    @Test
    fun commonPasswordsAreVeryWeak() {
        for (s in listOf("123456", "password", "qwertyuiop", "iloveyou", "woaini1314", "Tr0ub4dor&3", "Password123!", "aaaaaaaaaaaaaaaaaaaa")) {
            assertEquals(s, Level.VERY_WEAK, level(s))
        }
    }

    /** The meter cannot recognise famous lines, but it must not rate them strong either. */
    @Test
    fun famousLinesAreNotRatedStrong() {
        assertEquals(Level.VERY_WEAK, level("correct horse battery staple"))
        assertEquals(Level.VERY_WEAK, level("chuang qian ming yue guang"))
        assertTrue(level("To be or not to be that is the question") < Level.GOOD)
    }

    @Test
    fun longerPersonalSentencesGain() {
        val levels = listOf(
            "my cat is called mimi",
            "my first cat was called mimi and she was orange",
            "In 2009 Grandma Li and I picked 7 green dates (her yellow dog chased us)!",
        ).map(::level)
        assertEquals(levels.sorted(), levels)
        assertEquals(Level.VERY_WEAK, levels.first())
        assertEquals(Level.STRONG, levels.last())
    }

    @Test
    fun capitalsDigitsAndSymbolsCountMoreThanLowercase() {
        assertTrue(bits("Mimi9!") > bits("mimixy"))
    }

    @Test
    fun repetitionAddsAlmostNothing() {
        val once = bits("mydogishappy")
        assertTrue(bits("mydogishappymydogishappy") < once + 10)
        assertTrue(bits("abcdefgh") < 10)
    }

    @Test
    fun extraSpacesAreIgnoredLikeTheDerivation() {
        assertEquals(bits("correct horse"), bits("  correct   horse "), 0.0)
    }

    /** The goal behind Keyper's parameters: from about 48.4 bits on, over US$100 million in power. */
    @Test
    fun aHundredMillionDollarsSitsAtAbout48Bits() {
        for (s in listOf("my cat is called mimi", "my first cat was called mimi", "my first cat was called mimi and she was orange")) {
            val estimate = Strength.of(s)
            assertEquals(s, estimate.bits > 48.36, estimate.crackDollars() > 1e8)
        }
    }

    @Test
    fun crackTimeScalesWithGpus() {
        val s = Strength.of("correct horse battery staple")
        assertEquals(s.crackSeconds(1) / 1000, s.crackSeconds(1000), 1e-6 * s.crackSeconds(1000))
    }
}
