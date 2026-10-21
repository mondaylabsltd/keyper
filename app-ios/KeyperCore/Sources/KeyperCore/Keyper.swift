import CryptoKit
import Foundation

/// Keyper v1: (email, secret, domain constant) → BIP39 phrases. SPEC.md is the normative description.
///
/// Every constant here is part of the protocol: changing any of them changes every phrase ever
/// generated, so they may only change together with the version.
public enum Keyper {
    // About a minute on a phone, so that guessing a secret of about 48 bits already costs over
    // US$100 million in electricity alone (SPEC.md section 4).
    public static let iterations = 128
    public static let memoryKiB = 1024 * 1024
    public static let parallelism = 4
    public static let domainBytes = 32
    /// Minimum lengths of the normalised inputs.
    public static let minSecretLength = 12
    public static let minEmailLength = 6
    /// Besides ASCII letters and digits, a secret may use these 18 symbols: the ten above the digit
    /// keys and eight more chosen to be unmistakable (no quotes, `|`, `\`, `:` or `;`).
    public static let secretSymbols = "!@#$%^&*().,?-_+=/"
    static let saltPrefix = "keyper/v1:"

    public enum InputError: Error, Equatable {
        case emailTooShort, secretCharacters, secretTooShort, domainSize
    }

    /// The 32-byte key K that both phrase lengths are derived from (`mnemonic`), so one slow
    /// derivation serves both. `memory` is Argon2's working memory, `memoryKiB` KiB.
    public static func deriveKey(
        email: String,
        secret: String,
        domain: [UInt8],
        memory: UnsafeMutableRawBufferPointer? = nil,
        progress: ((_ done: Int, _ total: Int) -> Void)? = nil,
        isCancelled: () -> Bool = { false }
    ) throws -> [UInt8] {
        let e = normalizeEmail(email)
        let s = normalizeSecret(secret)
        guard e.unicodeScalars.count >= minEmailLength else { throw InputError.emailTooShort }
        guard s.unicodeScalars.allSatisfy({ isSecretScalar($0) || $0 == " " }) else { throw InputError.secretCharacters }
        guard s.unicodeScalars.count >= minSecretLength else { throw InputError.secretTooShort }
        guard domain.count == domainBytes else { throw InputError.domainSize }
        let password = hmac(key: domain, message: Array(s.utf8))
        let salt = Array((saltPrefix + e).utf8)
        return try Argon2id.hash(
            password: password, salt: salt, iterations: iterations, memoryKiB: memoryKiB, parallelism: parallelism,
            tagLength: 32, memory: memory, progress: progress, isCancelled: isCancelled
        )
    }

    /// The phrase of `words` words. Each length has its own entropy, keyed from K, so that one
    /// phrase reveals nothing about the other.
    public static func mnemonic(key: [UInt8], words: Int) -> [String] {
        precondition(words == 12 || words == 24, "words must be 12 or 24")
        let entropy = hmac(key: key, message: Array("keyper/v1 \(words) words".utf8))
        return Bip39.mnemonic(entropy: Array(entropy.prefix(words / 3 * 4)))
    }

    /// The secret is typed on Keyper's own keyboard: ASCII letters, digits, `secretSymbols` and
    /// spaces, all significant, except that leading and trailing spaces are dropped and a run of
    /// spaces counts as one, so an extra space can never make a recovery fail. Any other character
    /// makes the secret invalid.
    public static func normalizeSecret(_ secret: String) -> String {
        var out = String.UnicodeScalarView()
        var space = false
        for u in secret.unicodeScalars {
            if u == " " {
                space = !out.isEmpty
                continue
            }
            if space {
                out.append(" ")
                space = false
            }
            out.append(u)
        }
        return String(out)
    }

    public static func isSecretScalar(_ u: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(u) || ("A"..."Z").contains(u) || ("0"..."9").contains(u) || secretSymbols.unicodeScalars.contains(u)
    }

    public static func isSecretChar(_ c: Character) -> Bool {
        c.unicodeScalars.count == 1 && isSecretScalar(c.unicodeScalars.first!)
    }

    /// The email is only a salt: NFKC (which folds full-width forms, should one arrive from
    /// outside the app), then only ASCII letters and digits kept and lowercased, so dots, dashes,
    /// spaces and capitals never matter.
    public static func normalizeEmail(_ email: String) -> String {
        let kept = email.precomposedStringWithCompatibilityMapping.unicodeScalars.filter {
            ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0)
        }
        return String(String.UnicodeScalarView(kept)).lowercased()
    }

    /// A short fingerprint of the domain constant: two builds with the same one derive the same phrases.
    public static func domainId(_ domain: [UInt8]) -> String {
        let h = Array(SHA256.hash(data: domain))
        return String(format: "%02X%02X-%02X%02X", h[0], h[1], h[2], h[3])
    }

    static func hmac(key: [UInt8], message: [UInt8]) -> [UInt8] {
        Array(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key)))
    }
}
