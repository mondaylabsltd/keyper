import CryptoKit
import Testing
@testable import KeyperCore

struct KeyperTests {
    // Same vectors as SPEC.md, KeyperTest.kt and reference/keyper.py.
    let domain = (0..<32).map { UInt8($0) }

    // One at a time: each case maps 1 GiB.
    @Test(.enabled(if: optimized, "1 GiB per vector: run with swift test -c release"), .serialized,
          arguments: [
        ("alice@example.com", "correct horse battery staple",
         "a635fff88c3d798c504edad2ec95c5d9f276d9d05bd193d840778d1993dcdfcb",
         "bright blood connect stomach they proof cover armor usual adult clip hen",
         "evoke tiger live cycle donkey appear struggle gaze surround solid industry source brush hover daughter rib mobile tissue dwarf example unfold seven cook fiscal"),
        // The email's case and surrounding spaces drop out; extra spaces in the secret count as one.
        ("  Alice@Example.COM ", "correct horse  battery staple ",
         "a635fff88c3d798c504edad2ec95c5d9f276d9d05bd193d840778d1993dcdfcb",
         "bright blood connect stomach they proof cover armor usual adult clip hen",
         "evoke tiger live cycle donkey appear struggle gaze surround solid industry source brush hover daughter rib mobile tissue dwarf example unfold seven cook fiscal"),
        ("alice@example.com", "Correct horse battery staple",
         "b31450fc7df5731d49e358014def9866672a0d3f510ae729fb8e25aa6800dd47",
         "purpose sight afford hill tourist trap whale join error fog exhaust whip",
         "arrange anger swing glide armor hip master tourist science view panic fork thought police unique control crack panic stem finger advice govern little fire"),
        ("bob@example.com", "correct horse battery staple",
         "f423d8b47d734f59d3f91e9bdfcb02ceb7494f8355acabc3c93d0d18f0c34368",
         "expose ripple enjoy test buddy fine cheap like minute swing egg donkey",
         "eyebrow mule item news various message ladder maple trim census magnet endorse sudden young road blossom hybrid judge hammer tell address defense moral question"),
        ("a.lice+keyper@example.com", "Wo de di yi zhi mao jiao MiMi!",
         "2a089c83e6b0e9199992a853177cfb2024715c00674bbe3998dedeadf6283ab7",
         "differ talent quantum quiz coil alone cost unhappy enhance pave solution square",
         "best better ostrich report walnut this blade quiz torch army state shaft debate try legend merit minor lyrics donkey eyebrow quiz require quick pottery"),
        ("\u{ff21}\u{ff22}\u{ff23}.def@MAIL.com", "In 2009 (summer) Grandma Li & me @ 7am #42 $5 50%*^",
         "1cb9e296dd2c02b44a48e31adb72af2a4ef08691bd85806652d2f812435b8540",
         "park buddy sibling drip possible acoustic sniff unknown faith open drama abuse",
         "will awesome face pink bullet distance control plunge other basket frog wood duck ivory base vintage broken broken across solution race cheap later grocery"),
        ("carol@example.org", "Pi is 3.14, right? x+y=z / a-b_c",
         "937e3afe0e3066aade6b8896faab4ae7fe5c0ce84657776372b53ad622bb1529",
         "stairs bone hamster universe fury salmon million opera cliff mask supply damage",
         "burger rather afraid robot luggage amateur people frame clog review clump bacon heavy giraffe someone armed soap shaft town virus crouch about window able"),
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

    /// test-vectors/email.tsv, from reference/make_email_vectors.py: the same answer for every edge case.
    @Test func emailRuleMatchesTheSharedVectors() throws {
        let rows = try fixture("email.tsv")
        #expect(rows.count >= 50)
        for row in rows {
            let e = Keyper.normalizeEmail(String(decoding: row[0].unhex, as: UTF8.self))
            #expect((Keyper.isValidEmail(e) ? e : "-") == row[1], "\(row[2])")
        }
    }

    @Test func emailKeepsEveryCharacterButCase() {
        #expect(Keyper.normalizeEmail("  Alice@Example.COM ") == "alice@example.com")
        #expect(Keyper.normalizeEmail("\u{ff21}\u{ff22}\u{ff23}.def@MAIL.com") == "abc.def@mail.com") // full-width folds first
        #expect(Keyper.normalizeEmail("a.b@gmail.com") != Keyper.normalizeEmail("ab@gmail.com"))
        #expect(Keyper.normalizeEmail("ab@c.de") != Keyper.normalizeEmail("a@bc.de"))
        #expect(Keyper.normalizeEmail("\u{c9}ric@example.com") == "\u{c9}ric@example.com") // only ASCII is folded
    }

    @Test func rejectsInvalidInputsAndBadDomains() {
        let good = "Correct horse battery staple"
        #expect(throws: Keyper.InputError.emailInvalid) { try Keyper.deriveKey(email: "alice@example", secret: good, domain: domain) }
        #expect(throws: Keyper.InputError.emailInvalid) { try Keyper.deriveKey(email: "+86 138-0000-0000", secret: good, domain: domain) }
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
        #expect(Keyper.maxEmailLength == 254)
        #expect(Keyper.maxLocalLength == 64)
        #expect(Keyper.maxLabelLength == 63)
        #expect(Keyper.emailLocalSymbols == "._+-")
        #expect(Keyper.secretSymbols == "!@#$%^&*().,?-_+=/")
        #expect(Keyper.saltPrefix == "keyper/v1:")
    }

    /// The same vector as the Kotlin core's test (computed with Python's hmac).
    @Test func drillFingerprintIsKeyedWithK() {
        let k = (0..<32).map { UInt8($0) }
        #expect(Keyper.drillFingerprint(key: k, email: "alice@example.com", secret: "correct horse battery staple").hex
            == "b059efdcb01df79ad229dfbe5647554140d0c59825c738faf9d69742080471cd")
        // The inputs are normalised first, as for the phrase.
        #expect(Keyper.drillFingerprint(key: k, email: " Alice@Example.COM ", secret: "correct horse  battery staple ")
            == Keyper.drillFingerprint(key: k, email: "alice@example.com", secret: "correct horse battery staple"))
        // Another K, another fingerprint: without K it says nothing about the inputs.
        #expect(Keyper.drillFingerprint(key: [UInt8](repeating: 0, count: 32), email: "alice@example.com", secret: "correct horse battery staple").hex
            == "aa281a7df8a582a3b52a2438509b9ff44f905b68f285df1a65821d8de1adac51")
        // Not the plain hash the drill used to keep.
        let plain = Array(SHA256.hash(data: Array("alice@example.com\ncorrect horse battery staple".utf8)))
        #expect(plain != Keyper.drillFingerprint(key: k, email: "alice@example.com", secret: "correct horse battery staple"))
    }

    /// Length prefixes: pairs whose plain concatenation is the same string still differ.
    @Test func drillFingerprintEncodingIsUnambiguous() {
        let k = (0..<32).map { UInt8($0) }
        #expect(Keyper.drillFingerprint(key: k, email: "ab@c.de", secret: "fcorrect horse battery").hex
            == "f5c831ede2a4a714c632f6365e30566b6dc951659edda438c198b7e486a02906")
        #expect(Keyper.drillFingerprint(key: k, email: "ab@c.def", secret: "correct horse battery").hex
            == "87a42fce9027bbdc30f1c32a09409012ad0d6cfcc066d02548ad57f0036881cf")
    }

    @Test func secureZeroWipesWhatItIsGiven() {
        var bytes = [UInt8](repeating: 7, count: 100)
        var words = [UInt64](repeating: .max, count: 100)
        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: 1 << 20, alignment: 16)
        defer { raw.deallocate() }
        raw.initializeMemory(as: UInt8.self, repeating: 9)
        SecureZero.array(&bytes)
        SecureZero.array(&words)
        SecureZero.bytes(raw.baseAddress!, count: raw.count)
        #expect(bytes.allSatisfy { $0 == 0 })
        #expect(words.allSatisfy { $0 == 0 })
        #expect(raw.allSatisfy { $0 == 0 })
    }

    @Test func domainId() {
        #expect(Keyper.domainId(domain) == "630D-CD29")
    }
}
