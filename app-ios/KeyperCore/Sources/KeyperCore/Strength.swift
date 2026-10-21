import Foundation

/// An estimate of how hard a secret is to guess, for the app's meter; not part of the protocol.
///
/// It charges each character what a human-made sentence carries against a language model — about
/// 1.5 bits per lowercase letter of English or pinyin, not the 4.7 of a random one — a little more
/// for capitals, digits and symbols, and almost nothing for repeats and runs like "abc" or "123".
/// It cannot recognise quotes, lyrics, names or dates, so it still overrates those.
/// Shared with the Android app through test-vectors/strength.tsv.
public struct Strength: Sendable {
    public enum Level: Int, Comparable, Sendable {
        case veryWeak, weak, good, strong
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    public let bits: Double

    /// Graded by what an attacker would spend: under $1M, under $100M, under $100B, more.
    public var level: Level {
        let dollars = crackDollars()
        if dollars < 1e6 { return .veryWeak }
        if dollars < 1e8 { return .weak }
        if dollars < 1e11 { return .good }
        return .strong
    }

    /// Expected guesses: half the space.
    private var guesses: Double { pow(2, bits - 1) }

    /// Expected seconds for an attacker who has the app and the email, running `gpus` top GPUs.
    public func crackSeconds(gpus: Int) -> Double { guesses / (Double(gpus) * Strength.guessesPerGpuSecond) }

    /// Expected electricity bill of that attack in US dollars, hardware not included.
    public func crackDollars() -> Double { guesses * Strength.joulesPerGuess / 3.6e6 * Strength.usdPerKwh }

    // The attacker model, deliberately generous to the attacker: see SPEC.md section 4.
    public static let guessesPerGpuSecond = 20.0
    public static let joulesPerGuess = 40.0
    public static let usdPerKwh = 0.05

    public static func of(_ secret: String) -> Strength {
        // Spaces carry no information an attacker lacks: where words break follows from the words.
        let s = Keyper.normalizeSecret(secret).unicodeScalars.filter { $0 != " " }.map { Int($0.value) }
        var bits = 0.0
        var i = 0
        while i < s.count {
            let copy = longestEarlierMatch(s, i)
            if copy >= 3 {
                // Repeated text only costs a pointer back and a length.
                bits += log2(Double(i) + 1) + log2(Double(copy))
                i += copy
                continue
            }
            bits += i > 0 && abs(s[i] - s[i - 1]) <= 1 ? 1.0 : classBits(s[i])
            i += 1
        }
        return Strength(bits: bits)
    }

    private static func classBits(_ c: Int) -> Double {
        switch c {
        case 97...122: return 1.5 // a letter of an English or pinyin sentence
        case 65...90: return 2.0 // mostly where a word starts
        case 48...57: return 2.0 // years, dates and phone numbers rather than random digits
        default: return 3.0 // one of the symbols
        }
    }

    /// Length of the longest run starting at `i` that also starts somewhere before `i` (overlap allowed).
    private static func longestEarlierMatch(_ s: [Int], _ i: Int) -> Int {
        var best = 0
        for j in 0..<i {
            var n = 0
            while i + n < s.count && s[j + n] == s[i + n] { n += 1 }
            best = max(best, n)
        }
        return best
    }
}
