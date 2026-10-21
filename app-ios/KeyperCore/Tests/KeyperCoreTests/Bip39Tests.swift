import CryptoKit
import Testing
@testable import KeyperCore

struct Bip39Tests {
    @Test func wordlistIsTheOfficialOne() {
        let file = Array((bip39English.joined(separator: "\n") + "\n").utf8)
        #expect(Array(SHA256.hash(data: file)).hex == "2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda")
    }

    /// Trezor's reference vectors (python-mnemonic vectors.json).
    @Test func trezorVectors() throws {
        let rows = try fixture("bip39.tsv")
        #expect(rows.count == 24)
        for row in rows { #expect(Bip39.mnemonic(entropy: row[0].unhex).joined(separator: " ") == row[1]) }
    }

    @Test func everyLength() {
        for bytes in stride(from: 16, through: 32, by: 4) {
            #expect(Bip39.mnemonic(entropy: [UInt8](repeating: 0, count: bytes)).count == bytes * 3 / 4)
        }
    }
}
