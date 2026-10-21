import Dispatch

/// Argon2id, version 0x13 (RFC 9106).
///
/// Lanes are filled in parallel, one segment at a time, as the algorithm's synchronisation points
/// allow; each slice ends only when every lane has finished it, so no thread is left writing once
/// [hash] returns or throws. The memory may be supplied by the caller, so the app can map and unmap
/// it itself. [isCancelled] is checked before every slice.
public enum Argon2id {
    static let version: UInt32 = 0x13
    static let type: UInt32 = 2 // Argon2id
    static let slices = 4
    static let words = 128 // 64-bit words in a 1 KiB block

    public struct Cancelled: Error {}

    /// [memory] needs at least [memoryKiB] KiB; its contents are overwritten.
    /// [progress] is called on the calling thread after each of the iterations × 4 slices.
    public static func hash(
        password: [UInt8],
        salt: [UInt8],
        iterations: Int,
        memoryKiB: Int,
        parallelism: Int,
        tagLength: Int,
        secret: [UInt8] = [],
        associatedData: [UInt8] = [],
        memory: UnsafeMutableRawBufferPointer? = nil,
        progress: ((_ done: Int, _ total: Int) -> Void)? = nil,
        isCancelled: () -> Bool = { false }
    ) throws -> [UInt8] {
        precondition(iterations >= 1, "iterations must be at least 1")
        precondition((1...0xFFFFFF).contains(parallelism), "parallelism out of range")
        precondition(memoryKiB >= 8 * parallelism, "memory must be at least 8 KiB per lane")
        precondition(memoryKiB < 1 << 21, "memory must be below 2 GiB")
        precondition(tagLength >= 4, "tag must be at least 4 bytes")
        precondition(salt.count >= 8, "salt must be at least 8 bytes")

        let h0 = Blake2b(64)
            .update(UInt32(parallelism)).update(UInt32(tagLength)).update(UInt32(memoryKiB)).update(UInt32(iterations))
            .update(version).update(type)
            .update(UInt32(password.count)).update(password)
            .update(UInt32(salt.count)).update(salt)
            .update(UInt32(secret.count)).update(secret)
            .update(UInt32(associatedData.count)).update(associatedData)
            .digest()

        let segmentLength = memoryKiB / (slices * parallelism)
        let laneLength = segmentLength * slices
        let blockCount = laneLength * parallelism
        let words: UnsafeMutablePointer<UInt64>
        if let memory {
            precondition(memory.count >= memoryKiB * 1024, "memory buffer too small")
            words = memory.baseAddress!.bindMemory(to: UInt64.self, capacity: blockCount * Self.words)
        } else {
            words = .allocate(capacity: blockCount * Self.words)
        }
        defer { if memory == nil { words.deallocate() } }
        let m = Memory(words: words, parallelism: parallelism, segmentLength: segmentLength, iterations: iterations)

        for lane in 0..<parallelism {
            for i in 0..<2 {
                let bytes = hPrime(h0 + le32(UInt32(i)) + le32(UInt32(lane)), 1024)
                let block = m.block(lane, i)
                for k in 0..<Self.words { block[k] = readLE64(bytes, 8 * k) }
            }
        }

        for pass in 0..<iterations {
            for slice in 0..<slices {
                if isCancelled() { throw Cancelled() }
                DispatchQueue.concurrentPerform(iterations: parallelism) { lane in
                    m.fillSegment(pass: pass, slice: slice, lane: lane)
                }
                progress?(pass * slices + slice + 1, iterations * slices)
            }
        }

        var last = [UInt64](repeating: 0, count: Self.words)
        for lane in 0..<parallelism {
            let block = m.block(lane, laneLength - 1)
            for k in 0..<Self.words { last[k] ^= block[k] }
        }
        let bytes = (0..<1024).map { UInt8(truncatingIfNeeded: last[$0 / 8] >> (8 * UInt64($0 % 8))) }
        return hPrime(bytes, tagLength)
    }

    /// H' from RFC 9106 section 3.3: BLAKE2b stretched to any output length.
    static func hPrime(_ input: [UInt8], _ length: Int) -> [UInt8] {
        if length <= 64 { return Blake2b(length).update(UInt32(length)).update(input).digest() }
        var out = [UInt8]()
        out.reserveCapacity(length)
        let r = (length + 31) / 32 - 2
        var v = Blake2b(64).update(UInt32(length)).update(input).digest()
        out += v[0..<32]
        for _ in 1..<r {
            v = Blake2b(64).update(v).digest()
            out += v[0..<32]
        }
        out += Blake2b(length - 32 * r).update(v).digest()
        return out
    }

    /// The working memory: lane after lane, block after block, 128 words each.
    private struct Memory: @unchecked Sendable {
        let words: UnsafeMutablePointer<UInt64>
        let parallelism: Int
        let segmentLength: Int
        let iterations: Int
        var laneLength: Int { segmentLength * slices }

        @inline(__always)
        func block(_ lane: Int, _ index: Int) -> UnsafeMutablePointer<UInt64> {
            words + (lane * laneLength + index) * Argon2id.words
        }

        func fillSegment(pass: Int, slice: Int, lane: Int) {
            // Scratch blocks of this thread: two for the compression, three for address generation.
            let scratch = UnsafeMutablePointer<UInt64>.allocate(capacity: 5 * Argon2id.words)
            defer { scratch.deallocate() }
            scratch.initialize(repeating: 0, count: 5 * Argon2id.words)
            let r = scratch
            let z = scratch + Argon2id.words
            let zero = scratch + 2 * Argon2id.words
            let input = scratch + 3 * Argon2id.words
            let addresses = scratch + 4 * Argon2id.words

            let dataIndependent = pass == 0 && slice < slices / 2
            if dataIndependent {
                input[0] = UInt64(pass)
                input[1] = UInt64(lane)
                input[2] = UInt64(slice)
                input[3] = UInt64(laneLength * parallelism)
                input[4] = UInt64(iterations)
                input[5] = UInt64(Argon2id.type)
            }
            func nextAddresses() {
                input[6] &+= 1
                fillBlock(zero, input, addresses, xorInto: false, r, z)
                fillBlock(zero, addresses, addresses, xorInto: false, r, z)
            }

            // The first two blocks of every lane come from H0.
            let first = pass == 0 && slice == 0 ? 2 : 0
            if dataIndependent && first != 0 { nextAddresses() }

            var current = slice * segmentLength + first
            var prev = block(lane, current == 0 ? laneLength - 1 : current - 1)
            for index in first..<segmentLength {
                let random: UInt64
                if dataIndependent {
                    if index % Argon2id.words == 0 { nextAddresses() }
                    random = addresses[index % Argon2id.words]
                } else {
                    random = prev[0]
                }
                let refLane = pass == 0 && slice == 0 ? lane : Int((random >> 32) % UInt64(parallelism))
                let ref = block(refLane, referenceIndex(pass: pass, slice: slice, index: index, j1: random & 0xFFFF_FFFF, sameLane: refLane == lane))
                let next = block(lane, current)
                fillBlock(prev, ref, next, xorInto: pass > 0, r, z)
                prev = next
                current += 1
            }
        }

        /// Maps a 32-bit random value onto the blocks a new block may reference (RFC 9106 section 3.4.1.2).
        @inline(__always)
        func referenceIndex(pass: Int, slice: Int, index: Int, j1: UInt64, sameLane: Bool) -> Int {
            let finished = pass == 0 ? slice * segmentLength : laneLength - segmentLength
            let area: Int
            if sameLane {
                area = finished + index - 1
            } else if index == 0 {
                area = finished - 1
            } else {
                area = finished
            }
            let x = (j1 &* j1) >> 32
            let relative = UInt64(area) - 1 - ((UInt64(area) &* x) >> 32)
            let start = pass == 0 || slice == slices - 1 ? 0 : (slice + 1) * segmentLength
            return Int((UInt64(start) + relative) % UInt64(laneLength))
        }
    }

    /// The compression function G: out = P(x ^ y) ^ (x ^ y), additionally XORed into out's previous
    /// contents when [xorInto] (passes after the first). [r] and [z] are scratch; out may alias y.
    @inline(__always)
    static func fillBlock(
        _ x: UnsafeMutablePointer<UInt64>,
        _ y: UnsafeMutablePointer<UInt64>,
        _ out: UnsafeMutablePointer<UInt64>,
        xorInto: Bool,
        _ r: UnsafeMutablePointer<UInt64>,
        _ z: UnsafeMutablePointer<UInt64>
    ) {
        for k in 0..<words { r[k] = x[k] ^ y[k] }
        if xorInto {
            for k in 0..<words { z[k] = r[k] ^ out[k] }
        } else {
            for k in 0..<words { z[k] = r[k] }
        }
        for i in 0..<8 {
            let b = 16 * i
            round(r, b, b + 1, b + 2, b + 3, b + 4, b + 5, b + 6, b + 7, b + 8, b + 9, b + 10, b + 11, b + 12, b + 13, b + 14, b + 15)
        }
        for i in 0..<8 {
            let b = 2 * i
            round(r, b, b + 1, b + 16, b + 17, b + 32, b + 33, b + 48, b + 49, b + 64, b + 65, b + 80, b + 81, b + 96, b + 97, b + 112, b + 113)
        }
        for k in 0..<words { out[k] = z[k] ^ r[k] }
    }

    /// The BLAKE2b round without message words, on the 16 words of [v] at the given positions.
    @inline(__always)
    static func round(
        _ v: UnsafeMutablePointer<UInt64>,
        _ p0: Int, _ p1: Int, _ p2: Int, _ p3: Int, _ p4: Int, _ p5: Int, _ p6: Int, _ p7: Int,
        _ p8: Int, _ p9: Int, _ p10: Int, _ p11: Int, _ p12: Int, _ p13: Int, _ p14: Int, _ p15: Int
    ) {
        g(v, p0, p4, p8, p12)
        g(v, p1, p5, p9, p13)
        g(v, p2, p6, p10, p14)
        g(v, p3, p7, p11, p15)
        g(v, p0, p5, p10, p15)
        g(v, p1, p6, p11, p12)
        g(v, p2, p7, p8, p13)
        g(v, p3, p4, p9, p14)
    }

    @inline(__always)
    static func g(_ v: UnsafeMutablePointer<UInt64>, _ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        var va = v[a], vb = v[b], vc = v[c], vd = v[d]
        va = blaMka(va, vb); vd = rotr(vd ^ va, 32)
        vc = blaMka(vc, vd); vb = rotr(vb ^ vc, 24)
        va = blaMka(va, vb); vd = rotr(vd ^ va, 16)
        vc = blaMka(vc, vd); vb = rotr(vb ^ vc, 63)
        v[a] = va
        v[b] = vb
        v[c] = vc
        v[d] = vd
    }

    @inline(__always)
    static func blaMka(_ x: UInt64, _ y: UInt64) -> UInt64 {
        x &+ y &+ 2 &* (x & 0xFFFF_FFFF) &* (y & 0xFFFF_FFFF)
    }
}
