/// QR Code encoder (ISO/IEC 18004) reduced to what Keyper needs: byte mode, error correction level
/// M, versions 1...40, and the lowest-penalty mask. The same encoder as the Android app's, checked
/// against the same fixtures, so both draw identical symbols.
public struct QrCode: Sendable {
    public let size: Int
    private let modules: [Bool]

    /// True for a dark module; `x` is the column and `y` the row.
    public subscript(x: Int, y: Int) -> Bool { modules[y * size + x] }

    public static func encode(_ text: String) -> QrCode { encode(Array(text.utf8), mask: nil) }

    static func encode(_ data: [UInt8], mask: Int?) -> QrCode {
        guard let version = (1...40).first(where: { 4 + countBits($0) + 8 * data.count <= 8 * dataCodewords($0) }) else {
            preconditionFailure("\(data.count) bytes do not fit in a QR code")
        }
        let grid = Grid(version: version)
        grid.drawCodewords(addEcc(version, dataCodewords(version, data)))
        // The first of the lowest penalties, as the Android encoder picks it.
        let chosen = mask ?? (0..<8).map { (penalty(grid.masked($0), grid.size), $0) }.min(by: <)!.1
        return QrCode(size: grid.size, modules: grid.masked(chosen))
    }

    private static func countBits(_ version: Int) -> Int { version <= 9 ? 8 : 16 }

    /// Mode indicator, length, payload, terminator and pad bytes.
    private static func dataCodewords(_ version: Int, _ data: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: dataCodewords(version))
        var bit = 0
        func put(_ value: Int, _ n: Int) {
            for i in stride(from: n - 1, through: 0, by: -1) {
                if (value >> i) & 1 != 0 { out[bit / 8] |= UInt8(0x80 >> (bit % 8)) }
                bit += 1
            }
        }
        put(0b0100, 4)
        put(data.count, countBits(version))
        for b in data { put(Int(b), 8) }
        // Up to four terminator bits and the padding to a byte boundary are already zero.
        var pad: UInt8 = 0xEC
        for i in (min(bit + 4, 8 * out.count) + 7) / 8..<out.count {
            out[i] = pad
            pad ^= 0xEC ^ 0x11
        }
        return out
    }

    /// Splits data into blocks, appends Reed-Solomon codewords to each, and interleaves them.
    private static func addEcc(_ version: Int, _ data: [UInt8]) -> [UInt8] {
        let blocks = blockCount[version]
        let eccLength = eccPerBlock[version]
        let raw = rawDataModules(version) / 8
        let shortBlocks = blocks - raw % blocks
        let shortLength = raw / blocks // including ECC
        let divisor = rsDivisor(eccLength)
        var k = 0
        let split: [(data: [UInt8], ecc: [UInt8])] = (0..<blocks).map { i in
            let dataLength = shortLength - eccLength + (i < shortBlocks ? 0 : 1)
            let d = Array(data[k..<k + dataLength])
            k += dataLength
            return (d, rsRemainder(d, divisor))
        }
        var out = [UInt8]()
        out.reserveCapacity(raw)
        for i in 0...(shortLength - eccLength) {
            for block in split where i < block.data.count { out.append(block.data[i]) }
        }
        for i in 0..<eccLength {
            for block in split { out.append(block.ecc[i]) }
        }
        return out
    }

    private static func rsDivisor(_ degree: Int) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: degree)
        r[degree - 1] = 1
        var root = 1
        for _ in 0..<degree {
            for j in 0..<r.count {
                r[j] = UInt8(gfMul(Int(r[j]), root))
                if j + 1 < r.count { r[j] ^= r[j + 1] }
            }
            root = gfMul(root, 2)
        }
        return r
    }

    private static func rsRemainder(_ data: [UInt8], _ divisor: [UInt8]) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: divisor.count)
        for b in data {
            let factor = Int(b ^ r[0])
            r.removeFirst()
            r.append(0)
            for i in 0..<r.count { r[i] ^= UInt8(gfMul(Int(divisor[i]), factor)) }
        }
        return r
    }

    /// Multiplication in GF(2^8) modulo x^8 + x^4 + x^3 + x^2 + 1.
    private static func gfMul(_ x: Int, _ y: Int) -> Int {
        var z = 0
        for i in stride(from: 7, through: 0, by: -1) {
            z = (z << 1) ^ ((z >> 7) * 0x11D)
            z ^= ((y >> i) & 1) * x
        }
        return z
    }

    private static func rawDataModules(_ version: Int) -> Int {
        var r = (16 * version + 128) * version + 64
        if version >= 2 {
            let align = version / 7 + 2
            r -= (25 * align - 10) * align - 55
            if version >= 7 { r -= 36 }
        }
        return r
    }

    private static func dataCodewords(_ version: Int) -> Int {
        rawDataModules(version) / 8 - eccPerBlock[version] * blockCount[version]
    }

    // Error correction level M, indexed by version (index 0 unused).
    private static let eccPerBlock = [
        0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
        26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    ]
    private static let blockCount = [
        0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
        17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49,
    ]

    /// The symbol before masking: function patterns plus the placed codewords.
    private final class Grid {
        let version: Int
        let size: Int
        private var dark: [Bool]
        private var function: [Bool]

        init(version: Int) {
            self.version = version
            size = 4 * version + 17
            dark = [Bool](repeating: false, count: size * size)
            function = [Bool](repeating: false, count: size * size)
            for i in 0..<size {
                set(6, i, i % 2 == 0)
                set(i, 6, i % 2 == 0)
            }
            finder(3, 3)
            finder(size - 4, 3)
            finder(3, size - 4)
            let align = alignmentPositions()
            let last = align.count - 1
            for i in align.indices {
                for j in align.indices {
                    if i == 0 && j == 0 || i == 0 && j == last || i == last && j == 0 { continue }
                    for dy in -2...2 {
                        for dx in -2...2 { set(align[i] + dx, align[j] + dy, max(abs(dx), abs(dy)) != 1) }
                    }
                }
            }
            drawFormat(&dark, 0) // reserves the format area; the real bits depend on the mask
            if version >= 7 {
                var rem = version
                for _ in 0..<12 { rem = (rem << 1) ^ ((rem >> 11) * 0x1F25) }
                let bits = version << 12 | rem
                for i in 0..<18 {
                    let bit = (bits >> i) & 1 != 0
                    set(size - 11 + i % 3, i / 3, bit)
                    set(i / 3, size - 11 + i % 3, bit)
                }
            }
        }

        private func set(_ x: Int, _ y: Int, _ isDark: Bool) {
            dark[y * size + x] = isDark
            function[y * size + x] = true
        }

        private func finder(_ cx: Int, _ cy: Int) {
            for dy in -4...4 {
                for dx in -4...4 {
                    let x = cx + dx
                    let y = cy + dy
                    if (0..<size).contains(x) && (0..<size).contains(y) {
                        let d = max(abs(dx), abs(dy))
                        set(x, y, d != 2 && d != 4)
                    }
                }
            }
        }

        private func alignmentPositions() -> [Int] {
            if version == 1 { return [] }
            let n = version / 7 + 2
            let step = (version * 8 + n * 3 + 5) / (n * 4 - 4) * 2
            return (0..<n).map { $0 == 0 ? 6 : size - 7 - (n - 1 - $0) * step }
        }

        /// Places codeword bits in the two-column zigzag, skipping function modules.
        func drawCodewords(_ codewords: [UInt8]) {
            var i = 0
            var right = size - 1
            while right >= 1 {
                if right == 6 { right = 5 } // skip the vertical timing pattern
                let upward = (right + 1) & 2 == 0
                for vert in 0..<size {
                    let y = upward ? size - 1 - vert : vert
                    for x in stride(from: right, through: right - 1, by: -1) where !function[y * size + x] && i < codewords.count * 8 {
                        dark[y * size + x] = (codewords[i / 8] >> (7 - UInt8(i % 8))) & 1 != 0
                        i += 1
                    }
                }
                right -= 2
            }
        }

        func masked(_ mask: Int) -> [Bool] {
            var out = dark
            for y in 0..<size {
                for x in 0..<size where !function[y * size + x] && maskBit(mask, x, y) {
                    out[y * size + x].toggle()
                }
            }
            drawFormat(&out, mask)
            return out
        }

        /// Writes both copies of the 15 format bits (level M = 00, then the mask) and the dark module.
        private func drawFormat(_ m: inout [Bool], _ mask: Int) {
            var rem = mask
            for _ in 0..<10 { rem = (rem << 1) ^ ((rem >> 9) * 0x537) }
            let bits = (mask << 10 | rem) ^ 0x5412
            func put(_ x: Int, _ y: Int, _ i: Int) {
                m[y * size + x] = (bits >> i) & 1 != 0
                function[y * size + x] = true
            }
            for i in 0...5 { put(8, i, i) }
            put(8, 7, 6)
            put(8, 8, 7)
            put(7, 8, 8)
            for i in 9..<15 { put(14 - i, 8, i) }
            for i in 0..<8 { put(size - 1 - i, 8, i) }
            for i in 8..<15 { put(8, size - 15 + i, i) }
            m[(size - 8) * size + 8] = true
            function[(size - 8) * size + 8] = true
        }

        private func maskBit(_ mask: Int, _ x: Int, _ y: Int) -> Bool {
            switch mask {
            case 0: return (x + y) % 2 == 0
            case 1: return y % 2 == 0
            case 2: return x % 3 == 0
            case 3: return (x + y) % 3 == 0
            case 4: return (x / 3 + y / 2) % 2 == 0
            case 5: return x * y % 2 + x * y % 3 == 0
            case 6: return (x * y % 2 + x * y % 3) % 2 == 0
            default: return ((x + y) % 2 + x * y % 3) % 2 == 0
            }
        }
    }

    /// The standard mask penalty: long runs, 2x2 blocks, finder-like patterns, and dark/light imbalance.
    private static func penalty(_ m: [Bool], _ size: Int) -> Int {
        var score = 0
        for horizontal in [true, false] {
            for a in 0..<size {
                var history = [Int](repeating: 0, count: 7)
                var color = false
                var run = 0
                func push(_ length: Int) {
                    let withBorder = history[0] == 0 ? length + size : length // light border before the first run
                    history.removeLast()
                    history.insert(withBorder, at: 0)
                }
                for b in 0..<size {
                    let c = horizontal ? m[a * size + b] : m[b * size + a]
                    if c == color {
                        run += 1
                        if run == 5 { score += 3 } else if run > 5 { score += 1 }
                    } else {
                        push(run)
                        if !color { score += 40 * finderLike(history) }
                        color = c
                        run = 1
                    }
                }
                if color {
                    push(run)
                    run = 0
                }
                push(run + size) // light border after the last run
                score += 40 * finderLike(history)
            }
        }
        for y in 0..<size - 1 {
            for x in 0..<size - 1 {
                let c = m[y * size + x]
                if c == m[y * size + x + 1] && c == m[(y + 1) * size + x] && c == m[(y + 1) * size + x + 1] { score += 3 }
            }
        }
        let dark = m.filter { $0 }.count
        let total = size * size
        score += 10 * ((abs(dark * 20 - total * 10) + total - 1) / total - 1)
        return score
    }

    /// Counts 1:1:3:1:1 dark-light patterns with four light modules on either side.
    private static func finderLike(_ h: [Int]) -> Int {
        let n = h[1]
        let core = n > 0 && h[2] == n && h[3] == n * 3 && h[4] == n && h[5] == n
        return (core && h[0] >= n * 4 && h[6] >= n ? 1 : 0) + (core && h[6] >= n * 4 && h[0] >= n ? 1 : 0)
    }
}
