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
            "a635fff88c3d798c504edad2ec95c5d9f276d9d05bd193d840778d1993dcdfcb",
            "bright blood connect stomach they proof cover armor usual adult clip hen",
            "evoke tiger live cycle donkey appear struggle gaze surround solid industry source brush hover daughter rib mobile tissue dwarf example unfold seven cook fiscal",
        )
        check( // the email's case and surrounding spaces drop out; extra spaces in the secret count as one
            "  Alice@Example.COM ", "correct horse  battery staple ",
            "a635fff88c3d798c504edad2ec95c5d9f276d9d05bd193d840778d1993dcdfcb",
            "bright blood connect stomach they proof cover armor usual adult clip hen",
            "evoke tiger live cycle donkey appear struggle gaze surround solid industry source brush hover daughter rib mobile tissue dwarf example unfold seven cook fiscal",
        )
        check(
            "alice@example.com", "Correct horse battery staple",
            "b31450fc7df5731d49e358014def9866672a0d3f510ae729fb8e25aa6800dd47",
            "purpose sight afford hill tourist trap whale join error fog exhaust whip",
            "arrange anger swing glide armor hip master tourist science view panic fork thought police unique control crack panic stem finger advice govern little fire",
        )
        check(
            "bob@example.com", "correct horse battery staple",
            "f423d8b47d734f59d3f91e9bdfcb02ceb7494f8355acabc3c93d0d18f0c34368",
            "expose ripple enjoy test buddy fine cheap like minute swing egg donkey",
            "eyebrow mule item news various message ladder maple trim census magnet endorse sudden young road blossom hybrid judge hammer tell address defense moral question",
        )
        check(
            "a.lice+keyper@example.com", "Wo de di yi zhi mao jiao MiMi!",
            "2a089c83e6b0e9199992a853177cfb2024715c00674bbe3998dedeadf6283ab7",
            "differ talent quantum quiz coil alone cost unhappy enhance pave solution square",
            "best better ostrich report walnut this blade quiz torch army state shaft debate try legend merit minor lyrics donkey eyebrow quiz require quick pottery",
        )
        check(
            "\uff21\uff22\uff23.def@MAIL.com", "In 2009 (summer) Grandma Li & me @ 7am #42 \$5 50%*^",
            "1cb9e296dd2c02b44a48e31adb72af2a4ef08691bd85806652d2f812435b8540",
            "park buddy sibling drip possible acoustic sniff unknown faith open drama abuse",
            "will awesome face pink bullet distance control plunge other basket frog wood duck ivory base vintage broken broken across solution race cheap later grocery",
        )
        check(
            "carol@example.org", "Pi is 3.14, right? x+y=z / a-b_c",
            "937e3afe0e3066aade6b8896faab4ae7fe5c0ce84657776372b53ad622bb1529",
            "stairs bone hamster universe fury salmon million opera cliff mask supply damage",
            "burger rather afraid robot luggage amateur people frame clog review clump bacon heavy giraffe someone armed soap shaft town virus crouch about window able",
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

    /** test-vectors/email.tsv, from reference/make_email_vectors.py: the same answer for every edge case. */
    @Test
    fun emailRuleMatchesTheSharedVectors() {
        val rows = fixture("email.tsv")
        assertTrue(rows.size >= 50)
        for ((hex, expected, note) in rows) {
            val raw = String(hex.unhex(), Charsets.UTF_8)
            val e = Keyper.normalizeEmail(raw)
            assertEquals(note, expected, if (Keyper.isValidEmail(e)) e else "-")
        }
    }

    @Test
    fun emailKeepsEveryCharacterButCase() {
        assertEquals("alice@example.com", Keyper.normalizeEmail("  Alice@Example.COM "))
        assertEquals("abc.def@mail.com", Keyper.normalizeEmail("\uff21\uff22\uff23.def@MAIL.com")) // full-width folds first
        assertTrue(Keyper.normalizeEmail("a.b@gmail.com") != Keyper.normalizeEmail("ab@gmail.com"))
        assertTrue(Keyper.normalizeEmail("ab@c.de") != Keyper.normalizeEmail("a@bc.de"))
        assertEquals("\u00c9ric@example.com", Keyper.normalizeEmail("\u00c9ric@example.com")) // only ASCII is folded
    }

    @Test
    fun rejectsInvalidInputsAndBadDomains() {
        val good = "Correct horse battery staple"
        assertThrows(IllegalArgumentException::class.java) { Keyper.deriveKey("alice@example", good, domain) } // one label
        assertThrows(IllegalArgumentException::class.java) { Keyper.deriveKey("+86 138-0000-0000", good, domain) } // not an email
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
        assertEquals(frozen, 254, Keyper.MAX_EMAIL_LENGTH)
        assertEquals(frozen, 64, Keyper.MAX_LOCAL_LENGTH)
        assertEquals(frozen, 63, Keyper.MAX_LABEL_LENGTH)
        assertEquals(frozen, "._+-", Keyper.EMAIL_LOCAL_SYMBOLS)
        assertEquals(frozen, "!@#\$%^&*().,?-_+=/", Keyper.SECRET_SYMBOLS)
    }

    /** The same vector as the Swift core's test (computed with Python's hmac). */
    @Test
    fun drillFingerprintIsKeyedWithK() {
        val k = ByteArray(32) { it.toByte() }
        assertEquals("b059efdcb01df79ad229dfbe5647554140d0c59825c738faf9d69742080471cd",
            Keyper.drillFingerprint(k, "alice@example.com", "correct horse battery staple").hex())
        // The inputs are normalised first, as for the phrase.
        assertEquals(Keyper.drillFingerprint(k, "alice@example.com", "correct horse battery staple").hex(),
            Keyper.drillFingerprint(k, " Alice@Example.COM ", "correct horse  battery staple ").hex())
        // Another K, another fingerprint: without K it says nothing about the inputs.
        assertEquals("aa281a7df8a582a3b52a2438509b9ff44f905b68f285df1a65821d8de1adac51",
            Keyper.drillFingerprint(ByteArray(32), "alice@example.com", "correct horse battery staple").hex())
        // Not the plain hash the drill used to keep.
        val plain = java.security.MessageDigest.getInstance("SHA-256").digest("alice@example.com\ncorrect horse battery staple".toByteArray())
        assertTrue(!plain.contentEquals(Keyper.drillFingerprint(k, "alice@example.com", "correct horse battery staple")))
    }

    /** Length prefixes: pairs whose plain concatenation is the same string still differ. */
    @Test
    fun drillFingerprintEncodingIsUnambiguous() {
        val k = ByteArray(32) { it.toByte() }
        assertEquals("f5c831ede2a4a714c632f6365e30566b6dc951659edda438c198b7e486a02906",
            Keyper.drillFingerprint(k, "ab@c.de", "fcorrect horse battery").hex())
        assertEquals("87a42fce9027bbdc30f1c32a09409012ad0d6cfcc066d02548ad57f0036881cf",
            Keyper.drillFingerprint(k, "ab@c.def", "correct horse battery").hex())
    }

    @Test
    fun wipeZeroesEveryKindOfBuffer() {
        val bytes = ByteArray(100) { 7 }
        val longs = LongArray(100) { -1 }
        val buffer = java.nio.ByteBuffer.allocateDirect(1 shl 20).apply { while (hasRemaining()) put(9) }
        Wipe.bytes(bytes)
        Wipe.longs(longs)
        Wipe.buffer(buffer, buffer.capacity())
        assertTrue(bytes.all { it == 0.toByte() })
        assertTrue(longs.all { it == 0L })
        for (i in 0 until buffer.capacity()) assertEquals(0.toByte(), buffer.get(i))
    }

    @Test
    fun domainId() {
        assertEquals("630D-CD29", Keyper.domainId(domain))
    }
}
