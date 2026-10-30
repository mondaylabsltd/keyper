import Darwin

/// The one place sensitive buffers are overwritten with zeros: through `memset_s`, which C11
/// (Annex K) defines so that it is performed even when the memory is never read again, unlike a
/// loop of stores the optimiser may drop before a free. It covers the buffer it is given, nothing
/// else: a copy Swift made earlier (arrays copy on write) is out of its reach, which is why every
/// sensitive array here stays uniquely owned until it is wiped.
public enum SecureZero {
    public static func bytes(_ pointer: UnsafeMutableRawPointer, count: Int) {
        guard count > 0 else { return }
        _ = memset_s(pointer, count, 0, count)
    }

    public static func array(_ a: inout [UInt8]) {
        a.withUnsafeMutableBytes { if let base = $0.baseAddress { bytes(base, count: $0.count) } }
    }

    public static func array(_ a: inout [UInt64]) {
        a.withUnsafeMutableBytes { if let base = $0.baseAddress { bytes(base, count: $0.count) } }
    }
}
