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
    // About a minute on a Snapdragon 870, so that guessing a 49-bit secret already costs
    // over US$100 million in electricity alone (SPEC.md section 4).
    const val ITERATIONS = 128
    const val MEMORY_KIB = 1024 * 1024
    const val PARALLELISM = 4
    const val DOMAIN_BYTES = 32
    /** Minimum lengths of the normalised inputs. */
    const val MIN_SECRET_LENGTH = 12
    const val MIN_EMAIL_LENGTH = 6
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
        require(e.length >= MIN_EMAIL_LENGTH) { "email has fewer than $MIN_EMAIL_LENGTH letters and digits" }
        require(s.all { isSecretChar(it) || it == ' ' }) { "secret may only use ASCII letters, digits, $SECRET_SYMBOLS and spaces" }
        require(s.length >= MIN_SECRET_LENGTH) { "secret is shorter than $MIN_SECRET_LENGTH characters" }
        require(domain.size == DOMAIN_BYTES) { "domain constant must be $DOMAIN_BYTES bytes" }
        val password = hmac(domain, s.toByteArray(Charsets.UTF_8))
        val salt = (SALT_PREFIX + e).toByteArray(Charsets.UTF_8)
        return Argon2id.hash(password, salt, ITERATIONS, MEMORY_KIB, PARALLELISM, tagLength = 32, memory = memory, progress = progress)
    }

    /**
     * The phrase of [words] words. Each length has its own entropy, keyed from K, so that one
     * phrase reveals nothing about the other.
     */
    fun mnemonic(key: ByteArray, words: Int): List<String> {
        require(words == 12 || words == 24) { "words must be 12 or 24" }
        val entropy = hmac(key, "keyper/v1 $words words".toByteArray(Charsets.UTF_8))
        return Bip39.mnemonic(entropy.copyOf(words / 3 * 4))
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
     * The email is only a salt, typed on the system keyboard: NFKC (which folds full-width
     * forms), then only ASCII letters and digits kept and lowercased, so dots, dashes, spaces
     * and capitals never matter.
     */
    fun normalizeEmail(email: String): String =
        Normalizer.normalize(email, Normalizer.Form.NFKC)
            .filter { it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' }
            .lowercase()

    /** A short fingerprint of the domain constant: two builds with the same one derive the same phrases. */
    fun domainId(domain: ByteArray): String {
        val h = MessageDigest.getInstance("SHA-256").digest(domain)
        return "%02X%02X-%02X%02X".format(h[0], h[1], h[2], h[3])
    }

    private fun hmac(key: ByteArray, message: ByteArray): ByteArray =
        Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(key, "HmacSHA256")) }.doFinal(message)
}
