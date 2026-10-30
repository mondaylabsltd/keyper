package app.getkeyper.core

import java.nio.ByteBuffer
import java.security.MessageDigest
import java.text.Normalizer
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Keyper v1: (email, secret, domain constant) → BIP39 phrases. SPEC.md is the normative description.
 *
 * Every constant here is part of the protocol: changing any of them changes every
 * phrase ever generated, so they may only change together with the version.
 */
object Keyper {
    // About a minute on a Snapdragon 870, so that guessing a secret of about 48 bits already
    // costs over US$100 million in electricity alone (SPEC.md section 4).
    const val ITERATIONS = 128
    const val MEMORY_KIB = 1024 * 1024
    const val PARALLELISM = 4
    const val DOMAIN_BYTES = 32
    /** Minimum length of the normalised secret. */
    const val MIN_SECRET_LENGTH = 12
    /** Limits on the normalised email, in characters (SPEC.md section 2). */
    const val MAX_EMAIL_LENGTH = 254
    const val MAX_LOCAL_LENGTH = 64
    const val MAX_LABEL_LENGTH = 63
    /** Besides a–z and 0–9, the email's local part may use these; a domain label only '-'. */
    const val EMAIL_LOCAL_SYMBOLS = "._+-"
    /**
     * Besides ASCII letters and digits, a secret may use these 18 symbols: the ten above the digit
     * keys and eight more chosen to be unmistakable (no quotes, `|`, `\`, `:` or `;`).
     */
    const val SECRET_SYMBOLS = "!@#$%^&*().,?-_+=/"
    private const val SALT_PREFIX = "keyper/v1:"

    /**
     * The 32-byte key K that both phrase lengths are derived from ([mnemonic]), so one slow
     * derivation serves both.
     *
     * [memory] is Argon2's working memory, [MEMORY_KIB] KiB; Android passes an off-heap mapping.
     * [progress] reports (done, total) steps; interrupting the thread cancels.
     */
    fun deriveKey(
        email: String,
        secret: String,
        domain: ByteArray,
        memory: ByteBuffer = ByteBuffer.allocateDirect(MEMORY_KIB * 1024),
        progress: ((done: Int, total: Int) -> Unit)? = null,
    ): ByteArray {
        val e = normalizeEmail(email)
        val s = normalizeSecret(secret)
        require(isValidEmail(e)) { "not a valid email address (SPEC.md section 2)" }
        require(s.all { isSecretChar(it) || it == ' ' }) { "secret may only use ASCII letters, digits, $SECRET_SYMBOLS and spaces" }
        require(s.length >= MIN_SECRET_LENGTH) { "secret is shorter than $MIN_SECRET_LENGTH characters" }
        require(domain.size == DOMAIN_BYTES) { "domain constant must be $DOMAIN_BYTES bytes" }
        // P with the email is as good as the phrase: it lives only for the derivation.
        val password = hmac(domain, s.toByteArray(Charsets.UTF_8))
        val salt = (SALT_PREFIX + e).toByteArray(Charsets.UTF_8)
        try {
            return Argon2id.hash(password, salt, ITERATIONS, MEMORY_KIB, PARALLELISM, tagLength = 32, memory = memory, progress = progress)
        } finally {
            Wipe.bytes(password)
        }
    }

    /**
     * The phrase of [words] words. Each length has its own entropy, keyed from K, so that one
     * phrase reveals nothing about the other.
     */
    fun mnemonic(key: ByteArray, words: Int): List<String> {
        require(words == 12 || words == 24) { "words must be 12 or 24" }
        val entropy = hmac(key, "keyper/v1 $words words".toByteArray(Charsets.UTF_8))
        val part = entropy.copyOf(words / 3 * 4)
        try {
            return Bip39.mnemonic(part)
        } finally {
            Wipe.bytes(entropy) // the phrase in another form
            Wipe.bytes(part)
        }
    }

    /**
     * The secret is typed on Keyper's own keyboard: ASCII letters, digits, [SECRET_SYMBOLS] and
     * spaces, all significant, except that leading and trailing spaces are dropped and a run of
     * spaces counts as one, so an extra space can never make a recovery fail. Any other character
     * makes the secret invalid.
     */
    fun normalizeSecret(secret: String): String = secret.trim(' ').replace(SPACES, " ")

    private val SPACES = Regex(" +")

    fun isSecretChar(c: Char) = c in 'a'..'z' || c in 'A'..'Z' || c in '0'..'9' || c in SECRET_SYMBOLS

    /**
     * The email as it salts: NFKC (which folds full-width forms, should one arrive from outside
     * the app), leading and trailing spaces dropped and A–Z mapped to a–z. Every other character
     * counts, so two different addresses never share a salt. Check the result with [isValidEmail].
     */
    fun normalizeEmail(email: String): String =
        buildString {
            for (c in Normalizer.normalize(email, Normalizer.Form.NFKC).trim(' ')) append(if (c in 'A'..'Z') c + 32 else c)
        }

    /**
     * SPEC.md section 2: exactly one '@'; a local part of 1 to [MAX_LOCAL_LENGTH] characters from
     * a–z, 0–9 and [EMAIL_LOCAL_SYMBOLS], with no leading, trailing or doubled '.'; a domain of two
     * or more labels of 1 to [MAX_LABEL_LENGTH] characters from a–z, 0–9 and '-', none starting or
     * ending with '-', the last with a letter; at most [MAX_EMAIL_LENGTH] characters in all.
     */
    fun isValidEmail(normalized: String): Boolean {
        val e = normalized
        if (e.length > MAX_EMAIL_LENGTH || e.count { it == '@' } != 1) return false
        val (local, domain) = e.split('@')
        if (local.length !in 1..MAX_LOCAL_LENGTH || !local.all { isLowerAlnum(it) || it in EMAIL_LOCAL_SYMBOLS }) return false
        if (local.startsWith('.') || local.endsWith('.') || ".." in local) return false
        val labels = domain.split('.')
        if (labels.size < 2) return false
        for (label in labels) {
            if (label.length !in 1..MAX_LABEL_LENGTH || !label.all { isLowerAlnum(it) || it == '-' }) return false
            if (label.startsWith('-') || label.endsWith('-')) return false
        }
        return labels.last().any { it in 'a'..'z' }
    }

    private fun isLowerAlnum(c: Char) = c in 'a'..'z' || c in '0'..'9'

    /**
     * What the recovery drill compares, instead of keeping the sentence: HMAC-SHA256 keyed with K,
     * so it says nothing to anyone without K, and anyone with K has the phrase already. The message
     * is a label for domain separation, then the normalised email and secret, each prefixed with
     * its length in bytes (four, big-endian), so no two different pairs encode alike. Not part of
     * the protocol; it lives exactly as long as K does.
     */
    fun drillFingerprint(key: ByteArray, email: String, secret: String): ByteArray {
        val e = normalizeEmail(email).toByteArray(Charsets.UTF_8)
        val s = normalizeSecret(secret).toByteArray(Charsets.UTF_8)
        val message = ByteBuffer.allocate(DRILL_LABEL.size + 8 + e.size + s.size)
            .put(DRILL_LABEL).putInt(e.size).put(e).putInt(s.size).put(s).array()
        try {
            return hmac(key, message)
        } finally {
            Wipe.bytes(message)
            Wipe.bytes(s)
        }
    }

    private val DRILL_LABEL = "keyper/drill/v1\u0000".toByteArray(Charsets.UTF_8)

    /** A short fingerprint of the domain constant: two builds with the same one derive the same phrases. */
    fun domainId(domain: ByteArray): String {
        val h = MessageDigest.getInstance("SHA-256").digest(domain)
        return "%02X%02X-%02X%02X".format(h[0], h[1], h[2], h[3])
    }

    private fun hmac(key: ByteArray, message: ByteArray): ByteArray =
        Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(key, "HmacSHA256")) }.doFinal(message)
}
