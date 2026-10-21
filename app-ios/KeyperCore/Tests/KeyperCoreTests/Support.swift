import Foundation

extension String {
    var unhex: [UInt8] {
        var out = [UInt8]()
        var i = startIndex
        while i < endIndex {
            let j = index(i, offsetBy: 2)
            out.append(UInt8(self[i..<j], radix: 16)!)
            i = j
        }
        return out
    }
}

extension Array where Element == UInt8 {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

/// The repository root, for the fixtures shared with the Android app.
let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()

/// Rows of a tab-separated fixture in test-vectors/, without the # header.
func fixture(_ name: String) throws -> [[String]] {
    try String(contentsOf: repository.appendingPathComponent("test-vectors/\(name)"), encoding: .utf8)
        .split(separator: "\n", omittingEmptySubsequences: true)
        .filter { !$0.hasPrefix("#") }
        .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
}

/// The 1 GiB derivations take minutes unoptimised: run them with `swift test -c release`.
#if DEBUG
let optimized = false
#else
let optimized = true
#endif
