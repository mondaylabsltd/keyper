/// Unkeyed BLAKE2b (RFC 7693) with a digest length of 1...64 bytes.
final class Blake2b {
    private var h = Blake2b.iv
    private var m = [UInt64](repeating: 0, count: 16)
    private var v = [UInt64](repeating: 0, count: 16)
    private var buffer = [UInt8](repeating: 0, count: 128)
    private var buffered = 0
    private var counter: UInt64 = 0 // bytes compressed; Argon2 inputs never come near 2^64
    private let digestLength: Int

    init(_ digestLength: Int) {
        precondition((1...64).contains(digestLength))
        self.digestLength = digestLength
        h[0] ^= 0x0101_0000 ^ UInt64(digestLength)
    }

    @discardableResult
    func update(_ input: [UInt8]) -> Blake2b {
        var offset = 0
        while offset < input.count {
            // The final block must be compressed with the last-block flag, so a full
            // buffer is only flushed once more input is known to follow.
            if buffered == 128 {
                counter &+= 128
                compress(last: false)
                buffered = 0
            }
            let n = min(128 - buffered, input.count - offset)
            buffer.replaceSubrange(buffered..<buffered + n, with: input[offset..<offset + n])
            buffered += n
            offset += n
        }
        return self
    }

    /// Appends a 32-bit little-endian integer, as Argon2 does for all its lengths.
    @discardableResult
    func update(_ value: UInt32) -> Blake2b { update(le32(value)) }

    func digest() -> [UInt8] {
        counter &+= UInt64(buffered)
        for i in buffered..<128 { buffer[i] = 0 }
        compress(last: true)
        return (0..<digestLength).map { UInt8(truncatingIfNeeded: h[$0 / 8] >> (8 * UInt64($0 % 8))) }
    }

    private func compress(last: Bool) {
        for i in 0..<16 { m[i] = readLE64(buffer, 8 * i) }
        for i in 0..<8 {
            v[i] = h[i]
            v[i + 8] = Blake2b.iv[i]
        }
        v[12] ^= counter
        if last { v[14] = ~v[14] }
        for round in 0..<12 {
            let s = Blake2b.sigma[round % 10]
            g(0, 4, 8, 12, m[s[0]], m[s[1]])
            g(1, 5, 9, 13, m[s[2]], m[s[3]])
            g(2, 6, 10, 14, m[s[4]], m[s[5]])
            g(3, 7, 11, 15, m[s[6]], m[s[7]])
            g(0, 5, 10, 15, m[s[8]], m[s[9]])
            g(1, 6, 11, 12, m[s[10]], m[s[11]])
            g(2, 7, 8, 13, m[s[12]], m[s[13]])
            g(3, 4, 9, 14, m[s[14]], m[s[15]])
        }
        for i in 0..<8 { h[i] ^= v[i] ^ v[i + 8] }
    }

    private func g(_ a: Int, _ b: Int, _ c: Int, _ d: Int, _ x: UInt64, _ y: UInt64) {
        v[a] = v[a] &+ v[b] &+ x
        v[d] = rotr(v[d] ^ v[a], 32)
        v[c] = v[c] &+ v[d]
        v[b] = rotr(v[b] ^ v[c], 24)
        v[a] = v[a] &+ v[b] &+ y
        v[d] = rotr(v[d] ^ v[a], 16)
        v[c] = v[c] &+ v[d]
        v[b] = rotr(v[b] ^ v[c], 63)
    }

    private static let iv: [UInt64] = [
        0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
        0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
    ]

    private static let sigma: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
        [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
        [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
        [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
        [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
        [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
        [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
        [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
        [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
    ]
}

@inline(__always)
func rotr(_ x: UInt64, _ n: UInt64) -> UInt64 { (x >> n) | (x << (64 - n)) }

func le32(_ value: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> (8 * UInt32($0))) } }

func readLE64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
    var r: UInt64 = 0
    for i in (0..<8).reversed() { r = (r << 8) | UInt64(bytes[offset + i]) }
    return r
}
