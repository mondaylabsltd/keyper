import Testing
@testable import KeyperCore

struct KeyperTests {
    // Same vectors as SPEC.md, KeyperTest.kt and reference/keyper.py.
    let domain = (0..<32).map { UInt8($0) }

    // One at a time: each case maps 1 GiB.
    @Test(.enabled(if: optimized, "1 GiB per vector: run with swift test -c release"), .serialized,
          arguments: [
        ("alice@example.com", "correct horse battery staple",
         "127ed582829bb66d20e2a075c691722dbd582ec8cd4dc7c783cdff609f636a2d",
         "anchor amount there travel play salmon require soon crawl jelly index toddler",
         "hair pattern foam equip ethics gather margin trouble cheese lobster void employ mammal city apple lawn duck upgrade permit almost hurry list tortoise already"),
        // The email's case, dots and spaces drop out; extra spaces in the secret count as one.
        ("  Alice@Example.COM ", "correct horse  battery staple ",
         "127ed582829bb66d20e2a075c691722dbd582ec8cd4dc7c783cdff609f636a2d",
         "anchor amount there travel play salmon require soon crawl jelly index toddler",
         "hair pattern foam equip ethics gather margin trouble cheese lobster void employ mammal city apple lawn duck upgrade permit almost hurry list tortoise already"),
        ("alice@example.com", "Correct horse battery staple",
         "fb5495320579be258b82bde05db61f3717695e6643a6f130b954b61f58413b5e",
         "catalog soft salon best lock toy pool spend cool goat cradle vault",
         "trust spawn idle adult genius spider inner desert dignity weird chimney busy pledge become way dice water track teach machine vast potato burst swear"),
        ("bob@example.com", "correct horse battery staple",
         "ddd3a82317283ac110a07874b1e26751f7879e0cd242a6d57f92cff47bb49434",
         "spirit intact corn food lumber enrich bunker surface loan fatal eye mobile",
         "robot push razor sad father usage blind roof tennis tomato amazing blossom faculty spoon finger math claw hub hold diary knock merge base track"),
        ("+86 138-0000-0000", "Wo de di yi zhi mao jiao MiMi!",
         "61e3a82980320163e34008fb705a0670ca7ecc3cb42641a2a42f828fb345ab50",
         "buddy piano cluster cupboard crime luggage fall twenty olive choice nest crash",
         "essay game shove common length fatal window vote gesture east enemy direct biology equip exercise route return uncle target exercise firm style fly afford"),
        ("\u{ff21}\u{ff22}\u{ff23}.def@MAIL.com", "In 2009 (summer) Grandma Li & me @ 7am #42 $5 50%*^",
         "51d25d0e0f665370dd965c15bd8db5a8767b501419365801de1fc72fbb42bcbe",
         "sunset ginger poverty wage chef ritual craft donkey solid list safe heavy",
         "elder cost screen manage question message siren setup express decrease spin brass woman curve stamp ecology large pyramid brother spray blur poem rocket state"),
        ("carol@example.org", "Pi is 3.14, right? x+y=z / a-b_c",
         "8fb415ba4c2a4940ff140d0ce5955f1280e5acf910d7a7c11f43198bbb532366",
         "regret bench ticket bitter enforce dress skull aunt shiver maple friend spend",
         "canvas two army sugar pact dry design typical rib million supply baby merge siren shell beyond rack shallow sample salon melt orient box close"),
    ])
    func vectors(email: String, secret: String, key: String, words12: String, words24: String) throws {
        let k = try Keyper.deriveKey(email: email, secret: secret, domain: domain)
        #expect(k.hex == key)
        #expect(Keyper.mnemonic(key: k, words: 12).joined(separator: " ") == words12)
        #expect(Keyper.mnemonic(key: k, words: 24).joined(separator: " ") == words24)
    }

    @Test func secretCountsSpacesButNotExtraOnes() {
        #expect(Keyper.normalizeSecret(" correct horse  battery staple ") == "correct horse battery staple")
        #expect(Keyper.normalizeSecret("MiMi! (2009)") == "MiMi! (2009)")
        #expect(Keyper.normalizeSecret("my cat") != Keyper.normalizeSecret("mycat"))
        #expect("azAZ09!@#$%^&*().,?-_+=/".allSatisfy(Keyper.isSecretChar))
        for c in "'\"`|\\:;~<>[]{} \t\u{3002}\u{e9}\u{6211}" { #expect(!Keyper.isSecretChar(c), "'\(c)' must not be a secret character") }
    }

    @Test func emailKeepsOnlyAsciiLettersAndDigitsLowercased() {
        #expect(Keyper.normalizeEmail("  Alice@Example.COM ") == "aliceexamplecom")
        #expect(Keyper.normalizeEmail("+86 138-0000-0000") == "8613800000000")
        #expect(Keyper.normalizeEmail("\u{ff21}\u{ff22}\u{ff23}.def@MAIL.com") == "abcdefmailcom") // full-width folds first
        #expect(Keyper.normalizeEmail("a.b+x@gmail.com") == "abxgmailcom")
        #expect(Keyper.normalizeEmail("\u{5c0f}\u{660e}@\u{4f8b}\u{5b50}.\u{4e2d}\u{56fd}") == "")
    }

    @Test func rejectsInvalidInputsAndBadDomains() {
        let good = "Correct horse battery staple"
        #expect(throws: Keyper.InputError.emailTooShort) { try Keyper.deriveKey(email: "a@b.c", secret: good, domain: domain) }
        #expect(throws: Keyper.InputError.secretTooShort) { try Keyper.deriveKey(email: "alice@example.com", secret: "eleven char", domain: domain) }
        #expect(throws: Keyper.InputError.secretCharacters) { try Keyper.deriveKey(email: "alice@example.com", secret: good + ";", domain: domain) }
        #expect(throws: Keyper.InputError.secretCharacters) {
            try Keyper.deriveKey(email: "alice@example.com", secret: "\u{6211}\u{7684}\u{7b2c}\u{4e00}\u{53ea}\u{732b}\u{53eb}\u{54aa}\u{54aa}\u{5b83}\u{662f}\u{6a58}", domain: domain)
        }
        #expect(throws: Keyper.InputError.domainSize) { try Keyper.deriveKey(email: "alice@example.com", secret: good, domain: [UInt8](repeating: 0, count: 16)) }
    }

    /// One phrase must reveal nothing about the other length's.
    @Test func twelveAndTwentyFourWordsAreIndependent() {
        let key = (0..<32).map { UInt8(truncatingIfNeeded: $0 * 7) }
        #expect(Array(Keyper.mnemonic(key: key, words: 24).prefix(11)) != Array(Keyper.mnemonic(key: key, words: 12).prefix(11)))
    }

    /// SPEC.md: v1 is frozen. Changing any of these changes every phrase anyone has.
    @Test func protocolV1IsFrozen() {
        #expect(Keyper.iterations == 128)
        #expect(Keyper.memoryKiB == 1024 * 1024)
        #expect(Keyper.parallelism == 4)
        #expect(Keyper.domainBytes == 32)
        #expect(Keyper.minSecretLength == 12)
        #expect(Keyper.minEmailLength == 6)
        #expect(Keyper.secretSymbols == "!@#$%^&*().,?-_+=/")
        #expect(Keyper.saltPrefix == "keyper/v1:")
    }

    @Test func domainId() {
        #expect(Keyper.domainId(domain) == "630D-CD29")
    }
}
