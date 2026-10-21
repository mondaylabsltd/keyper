import Foundation
import Testing
@testable import KeyperCore

struct Argon2idTests {
    @Test func blake2b() {
        #expect(Blake2b(64).digest().hex ==
            "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419" +
            "d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce")
        #expect(Blake2b(64).update(Array("abc".utf8)).digest().hex ==
            "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1" +
            "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923")
        // Feeding in pieces across the 128-byte block boundary must not matter.
        let data = (0..<300).map { UInt8($0 & 0xFF) }
        #expect(Blake2b(32).update(data).digest() ==
            Blake2b(32).update(Array(data[0..<128])).update(Array(data[128..<129])).update(Array(data[129..<300])).digest())
    }

    /// RFC 9106 section 5.3, which also covers the secret and associated-data inputs.
    @Test func rfc9106() throws {
        let tag = try Argon2id.hash(
            password: [UInt8](repeating: 1, count: 32), salt: [UInt8](repeating: 2, count: 16),
            iterations: 3, memoryKiB: 32, parallelism: 4, tagLength: 32,
            secret: [UInt8](repeating: 3, count: 8), associatedData: [UInt8](repeating: 4, count: 12)
        )
        #expect(tag.hex == "0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659")
    }

    /// Cancelling stops at the next slice, and hash returns only once every lane is done.
    @Test func cancelStopsAtTheNextSlice() {
        var slices = 0
        #expect(throws: Argon2id.Cancelled.self) {
            try Argon2id.hash(
                password: [UInt8](repeating: 0, count: 32), salt: [UInt8](repeating: 0, count: 16),
                iterations: 1000, memoryKiB: 4096, parallelism: 4, tagLength: 32,
                progress: { done, _ in slices = done },
                isCancelled: { slices >= 8 }
            )
        }
        #expect(slices == 8)
    }

    /// Random parameters against argon2-cffi (reference/make_fixtures.py).
    @Test func matchesReferenceImplementation() throws {
        let rows = try fixture("argon2id.tsv")
        #expect(rows.count == 48)
        for row in rows {
            let (t, m, p) = (Int(row[0])!, Int(row[1])!, Int(row[2])!)
            let got = try Argon2id.hash(password: row[3].unhex, salt: row[4].unhex, iterations: t, memoryKiB: m, parallelism: p, tagLength: Int(row[5])!)
            #expect(got.hex == row[6], "t=\(t) m=\(m) p=\(p)")
        }
    }
}
