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
    /// Limits on the normalised email, in characters (SPEC.md section 2).
    public static let maxEmailLength = 254
    public static let maxLocalLength = 64
    public static let maxLabelLength = 63
    /// Besides a–z and 0–9, the email's local part may use these; a domain label only "-".
    public static let emailLocalSymbols = "._+-"
    /// Besides ASCII letters and digits, a secret may use these 18 symbols: the ten above the digit
    /// keys and eight more chosen to be unmistakable (no quotes, `|`, `\`, `:` or `;`).
    public static let secretSymbols = "!@#$%^&*().,?-_+=/"
    static let saltPrefix = "keyper/v1:"

    public enum InputError: Error, Equatable {
        case emailInvalid, secretCharacters, secretTooShort, domainSize
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
        guard isValidEmail(e) else { throw InputError.emailInvalid }
        guard s.unicodeScalars.allSatisfy({ isSecretScalar($0) || $0 == " " }) else { throw InputError.secretCharacters }
        guard s.unicodeScalars.count >= minSecretLength else { throw InputError.secretTooShort }
        guard domain.count == domainBytes else { throw InputError.domainSize }
        // P with the email is as good as the phrase: it lives only for the derivation.
        var password = hmac(key: domain, message: Array(s.utf8))
        defer { SecureZero.array(&password) }
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
        var entropy = hmac(key: key, message: Array("keyper/v1 \(words) words".utf8))
        var part = Array(entropy.prefix(words / 3 * 4))
        defer { // the phrase in another form
            SecureZero.array(&entropy)
            SecureZero.array(&part)
        }
        return Bip39.mnemonic(entropy: part)
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

    /// The email as it salts: NFKC (which folds full-width forms, should one arrive from outside
    /// the app), leading and trailing spaces dropped and A–Z mapped to a–z. Every other character
    /// counts, so two different addresses never share a salt. Check the result with `isValidEmail`.
    public static func normalizeEmail(_ email: String) -> String {
        var scalars = Array(email.precomposedStringWithCompatibilityMapping.unicodeScalars)
        while scalars.first == " " { scalars.removeFirst() }
        while scalars.last == " " { scalars.removeLast() }
        let folded = scalars.map { ("A"..."Z").contains($0) ? Unicode.Scalar($0.value + 32)! : $0 }
        return String(String.UnicodeScalarView(folded))
    }

    /// SPEC.md section 2: exactly one "@"; a local part of 1 to `maxLocalLength` characters from
    /// a–z, 0–9 and `emailLocalSymbols`, with no leading, trailing or doubled "."; a domain of two
    /// or more labels of 1 to `maxLabelLength` characters from a–z, 0–9 and "-", none starting or
    /// ending with "-", the last with a letter; at most `maxEmailLength` characters in all.
    public static func isValidEmail(_ normalized: String) -> Bool {
        let e = Array(normalized.unicodeScalars)
        guard e.count <= maxEmailLength, e.filter({ $0 == "@" }).count == 1, let at = e.firstIndex(of: "@") else { return false }
        let local = Array(e[..<at]), domain = Array(e[(at + 1)...])
        let symbols = Set(emailLocalSymbols.unicodeScalars)
        guard (1...maxLocalLength).contains(local.count), local.allSatisfy({ isLowerAlnum($0) || symbols.contains($0) }) else { return false }
        guard local.first != ".", local.last != ".", !zip(local, local.dropFirst()).contains(where: { $0 == "." && $1 == "." }) else { return false }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            guard (1...maxLabelLength).contains(label.count), label.allSatisfy({ isLowerAlnum($0) || $0 == "-" }) else { return false }
            guard label.first != "-", label.last != "-" else { return false }
        }
        return labels[labels.count - 1].contains { ("a"..."z").contains($0) }
    }

    static func isLowerAlnum(_ c: Unicode.Scalar) -> Bool { ("a"..."z").contains(c) || ("0"..."9").contains(c) }

    /// A short fingerprint of the domain constant: two builds with the same one derive the same phrases.
    public static func domainId(_ domain: [UInt8]) -> String {
        let h = Array(SHA256.hash(data: domain))
        return String(format: "%02X%02X-%02X%02X", h[0], h[1], h[2], h[3])
    }

    /// What the recovery drill compares, instead of keeping the sentence: HMAC-SHA256 keyed with K,
    /// so it says nothing to anyone without K, and anyone with K has the phrase already. The message
    /// is a label for domain separation, then the normalised email and secret, each prefixed with
    /// its length in bytes (four, big-endian), so no two different pairs encode alike. Not part of
    /// the protocol; it lives exactly as long as K does.
    public static func drillFingerprint(key: [UInt8], email: String, secret: String) -> [UInt8] {
        let e = Array(normalizeEmail(email).utf8)
        var s = Array(normalizeSecret(secret).utf8)
        var message = drillLabel + be32(e.count) + e + be32(s.count) + s
        defer {
            SecureZero.array(&message)
            SecureZero.array(&s)
        }
        return hmac(key: key, message: message)
    }

    static let drillLabel = Array("keyper/drill/v1\u{0}".utf8)

    static func be32(_ n: Int) -> [UInt8] { [UInt8(n >> 24 & 0xff), UInt8(n >> 16 & 0xff), UInt8(n >> 8 & 0xff), UInt8(n & 0xff)] }

    static func hmac(key: [UInt8], message: [UInt8]) -> [UInt8] {
        Array(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key)))
    }
}
