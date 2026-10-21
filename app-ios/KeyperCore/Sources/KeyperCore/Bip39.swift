import CryptoKit

/// BIP39 entropy-to-mnemonic encoding with the English wordlist.
public enum Bip39 {
    /// Encodes 16, 20, 24, 28 or 32 bytes of entropy as 12, 15, 18, 21 or 24 words.
    public static func mnemonic(entropy: [UInt8]) -> [String] {
        precondition((16...32).contains(entropy.count) && entropy.count % 4 == 0, "entropy must be 16...32 bytes, a multiple of 4")
        // ENT bits followed by ENT/32 checksum bits; the checksum never exceeds one byte.
        let bits = entropy + [Array(SHA256.hash(data: entropy))[0]]
        let count = (entropy.count * 8 + entropy.count / 4) / 11
        return (0..<count).map { bip39English[readBits(bits, 11 * $0, 11)] }
    }

    private static func readBits(_ bytes: [UInt8], _ start: Int, _ length: Int) -> Int {
        var r = 0
        for i in start..<start + length { r = (r << 1) | Int((bytes[i / 8] >> (7 - UInt8(i % 8))) & 1) }
        return r
    }
}
