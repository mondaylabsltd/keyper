package app.getkeyper.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class KeyperTest {
    // Same vectors as SPEC.md and reference/keyper.py.
    private val domain = ByteArray(32) { it.toByte() }

    private fun check(email: String, secret: String, entropy: String, words12: String, words24: String) {
        val e = Keyper.deriveKey(email, secret, domain)
        assertEquals(entropy, e.hex())
        assertEquals(words12, Keyper.mnemonic(e, 12).joinToString(" "))
        assertEquals(words24, Keyper.mnemonic(e, 24).joinToString(" "))
    }

    @Test
    fun vectors() {
        check(
            "alice@example.com", "correct horse battery staple",
            "127ed582829bb66d20e2a075c691722dbd582ec8cd4dc7c783cdff609f636a2d",
            "anchor amount there travel play salmon require soon crawl jelly index toddler",
            "hair pattern foam equip ethics gather margin trouble cheese lobster void employ mammal city apple lawn duck upgrade permit almost hurry list tortoise already",
        )
        check( // the email's case, dots and spaces drop out; extra spaces in the secret count as one
            "  Alice@Example.COM ", "correct horse  battery staple ",
            "127ed582829bb66d20e2a075c691722dbd582ec8cd4dc7c783cdff609f636a2d",
            "anchor amount there travel play salmon require soon crawl jelly index toddler",
            "hair pattern foam equip ethics gather margin trouble cheese lobster void employ mammal city apple lawn duck upgrade permit almost hurry list tortoise already",
        )
        check(
            "alice@example.com", "Correct horse battery staple",
            "fb5495320579be258b82bde05db61f3717695e6643a6f130b954b61f58413b5e",
            "catalog soft salon best lock toy pool spend cool goat cradle vault",
            "trust spawn idle adult genius spider inner desert dignity weird chimney busy pledge become way dice water track teach machine vast potato burst swear",
        )
        check(
            "bob@example.com", "correct horse battery staple",
            "ddd3a82317283ac110a07874b1e26751f7879e0cd242a6d57f92cff47bb49434",
            "spirit intact corn food lumber enrich bunker surface loan fatal eye mobile",
            "robot push razor sad father usage blind roof tennis tomato amazing blossom faculty spoon finger math claw hub hold diary knock merge base track",
        )
        check(
            "+86 138-0000-0000", "Wo de di yi zhi mao jiao MiMi!",
            "61e3a82980320163e34008fb705a0670ca7ecc3cb42641a2a42f828fb345ab50",
            "buddy piano cluster cupboard crime luggage fall twenty olive choice nest crash",
            "essay game shove common length fatal window vote gesture east enemy direct biology equip exercise route return uncle target exercise firm style fly afford",
        )
        check(
            "\uff21\uff22\uff23.def@MAIL.com", "In 2009 (summer) Grandma Li & me @ 7am #42 \$5 50%*^",
            "51d25d0e0f665370dd965c15bd8db5a8767b501419365801de1fc72fbb42bcbe",
            "sunset ginger poverty wage chef ritual craft donkey solid list safe heavy",
            "elder cost screen manage question message siren setup express decrease spin brass woman curve stamp ecology large pyramid brother spray blur poem rocket state",
        )
        check(
            "carol@example.org", "Pi is 3.14, right? x+y=z / a-b_c",
            "8fb415ba4c2a4940ff140d0ce5955f1280e5acf910d7a7c11f43198bbb532366",
            "regret bench ticket bitter enforce dress skull aunt shiver maple friend spend",
            "canvas two army sugar pact dry design typical rib million supply baby merge siren shell beyond rack shallow sample salon melt orient box close",
        )
    }

    @Test
    fun secretCountsSpacesButNotExtraOnes() {
        assertEquals("correct horse battery staple", Keyper.normalizeSecret(" correct horse  battery staple "))
        assertEquals("MiMi! (2009)", Keyper.normalizeSecret("MiMi! (2009)"))
        assertTrue(Keyper.normalizeSecret("my cat") != Keyper.normalizeSecret("mycat"))
        assertTrue("azAZ09!@#\$%^&*().,?-_+=/".all(Keyper::isSecretChar))
        for (c in "'\"`|\\:;~<>[]{} \t\u3002\u00e9\u6211") assertTrue("'$c' must not be a secret character", !Keyper.isSecretChar(c))
    }

    @Test
    fun emailKeepsOnlyAsciiLettersAndDigitsLowercased() {
        assertEquals("aliceexamplecom", Keyper.normalizeEmail("  Alice@Example.COM "))
        assertEquals("8613800000000", Keyper.normalizeEmail("+86 138-0000-0000"))
        assertEquals("abcdefmailcom", Keyper.normalizeEmail("\uff21\uff22\uff23.def@MAIL.com")) // full-width folds first
        assertEquals("abxgmailcom", Keyper.normalizeEmail("a.b+x@gmail.com"))
        assertEquals("", Keyper.normalizeEmail("\u5c0f\u660e@\u4f8b\u5b50.\u4e2d\u56fd"))
    }

    @Test
    fun rejectsInvalidInputsAndBadDomains() {
        val good = "Correct horse battery staple"
        assertThrows(IllegalArgumentException::class.java) { Keyper.deriveKey("a@b.c", good, domain) } // 3 letters
        assertThrows(IllegalArgumentException::class.java) { Keyper.deriveKey("alice@example.com", "eleven char", domain) } // 11
        assertThrows(IllegalArgumentException::class.java) { Keyper.deriveKey("alice@example.com", "$good;", domain) } // ';'
        assertThrows(IllegalArgumentException::class.java) { Keyper.deriveKey("alice@example.com", "\u6211\u7684\u7b2c\u4e00\u53ea\u732b\u53eb\u54aa\u54aa\u5b83\u662f\u6a58", domain) }
        assertThrows(IllegalArgumentException::class.java) { Keyper.deriveKey("alice@example.com", good, ByteArray(16)) }
    }

    /** One phrase must reveal nothing about the other length's. */
    @Test
    fun twelveAndTwentyFourWordsAreIndependent() {
        val key = ByteArray(32) { (it * 7).toByte() }
        val twelve = Keyper.mnemonic(key, 12)
        val twentyFour = Keyper.mnemonic(key, 24)
        assertTrue(twentyFour.take(11) != twelve.take(11))
    }

    /** SPEC.md: v1 is frozen. Changing any of these changes every phrase anyone has. */
    @Test
    fun protocolV1IsFrozen() {
        val frozen = "Keyper v1 is frozen (SPEC.md); this change would alter every user's phrase"
        assertEquals(frozen, 128, Keyper.ITERATIONS)
        assertEquals(frozen, 1024 * 1024, Keyper.MEMORY_KIB)
        assertEquals(frozen, 4, Keyper.PARALLELISM)
        assertEquals(frozen, 32, Keyper.DOMAIN_BYTES)
        assertEquals(frozen, 12, Keyper.MIN_SECRET_LENGTH)
        assertEquals(frozen, 6, Keyper.MIN_EMAIL_LENGTH)
        assertEquals(frozen, "!@#\$%^&*().,?-_+=/", Keyper.SECRET_SYMBOLS)
    }

    @Test
    fun domainId() {
        assertEquals("630D-CD29", Keyper.domainId(domain))
    }
}
