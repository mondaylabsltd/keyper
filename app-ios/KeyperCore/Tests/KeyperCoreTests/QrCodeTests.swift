import Testing
@testable import KeyperCore

struct QrCodeTests {
    /// Module-for-module against segno, for every version 1...40 and every mask (reference/make_fixtures.py).
    @Test func matchesSegno() throws {
        let rows = try fixture("qr.tsv")
        #expect(Set(rows.map { $0[1] }).count == 40)
        for row in rows {
            let (text, version, mask, hex) = (row[0], Int(row[1])!, Int(row[2])!, row[3])
            let qr = QrCode.encode(Array(text.utf8), mask: mask)
            let size = 4 * version + 17
            #expect(qr.size == size, "size of version \(version)")
            let bits = hex.flatMap { c -> [Bool] in
                let v = Int(String(c), radix: 16)!
                return (0..<4).map { (v >> (3 - $0)) & 1 == 1 }
            }
            var mismatches = 0
            for y in 0..<size { for x in 0..<size where bits[y * size + x] != qr[x, y] { mismatches += 1 } }
            #expect(mismatches == 0, "version \(version) mask \(mask)")
        }
    }

    @Test func longestMnemonicFits() {
        let words = [String](repeating: "abstract", count: 24).joined(separator: " ") // 215 bytes
        #expect(QrCode.encode(words).size <= 4 * 11 + 17)
    }
}
