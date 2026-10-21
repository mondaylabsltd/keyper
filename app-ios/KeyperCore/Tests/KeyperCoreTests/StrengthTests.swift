import Testing
@testable import KeyperCore

struct StrengthTests {
    private func bits(_ s: String) -> Double { Strength.of(s).bits }
    private func level(_ s: String) -> Strength.Level { Strength.of(s).level }

    @Test func commonPasswordsAreVeryWeak() {
        for s in ["123456", "password", "qwertyuiop", "iloveyou", "woaini1314", "Tr0ub4dor&3", "Password123!", "aaaaaaaaaaaaaaaaaaaa"] {
            #expect(level(s) == .veryWeak, "\(s)")
        }
    }

    /// The meter cannot recognise famous lines, but it must not rate them strong either.
    @Test func famousLinesAreNotRatedStrong() {
        #expect(level("correct horse battery staple") == .veryWeak)
        #expect(level("chuang qian ming yue guang") == .veryWeak)
        #expect(level("To be or not to be that is the question") < .good)
    }

    @Test func longerPersonalSentencesGain() {
        let levels = [
            "my cat is called mimi",
            "my first cat was called mimi and she was orange",
            "In 2009 Grandma Li and I picked 7 green dates (her yellow dog chased us)!",
        ].map(level)
        #expect(levels == levels.sorted())
        #expect(levels.first == .veryWeak)
        #expect(levels.last == .strong)
    }

    @Test func capitalsDigitsAndSymbolsCountMoreThanLowercase() {
        #expect(bits("Mimi9!") > bits("mimixy"))
    }

    @Test func repetitionAddsAlmostNothing() {
        let once = bits("mydogishappy")
        #expect(bits("mydogishappymydogishappy") < once + 10)
        #expect(bits("abcdefgh") < 10)
    }

    @Test func extraSpacesAreIgnoredLikeTheDerivation() {
        #expect(bits("correct horse") == bits("  correct   horse "))
    }

    /// The goal behind Keyper's parameters: from about 48.4 bits on, over US$100 million in power.
    @Test func aHundredMillionDollarsSitsAtAbout48Bits() {
        for s in ["my cat is called mimi", "my first cat was called mimi", "my first cat was called mimi and she was orange"] {
            let estimate = Strength.of(s)
            #expect((estimate.bits > 48.36) == (estimate.crackDollars() > 1e8), "\(s)")
        }
    }

    @Test func crackTimeScalesWithGpus() {
        let s = Strength.of("correct horse battery staple")
        #expect(abs(s.crackSeconds(gpus: 1) / 1000 - s.crackSeconds(gpus: 1000)) <= 1e-6 * s.crackSeconds(gpus: 1000))
    }
}
