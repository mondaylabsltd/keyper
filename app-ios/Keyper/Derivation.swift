import CryptoKit
import Foundation
import KeyperCore
import os
import UIKit

/// What the model needs of a derivation: start it once, cancel it. Unit tests stand in a fake for
/// the minute-long run; the app only ever uses Derivation.
protocol KeyDerivation: AnyObject {
    /// [progress] and [completion] are called on the main queue.
    func start(
        email: String,
        secret: String,
        domain: [UInt8],
        progress: @escaping @Sendable (_ done: Int, _ total: Int, _ elapsed: TimeInterval) -> Void,
        completion: @escaping @Sendable (Result<[UInt8], Error>) -> Void
    )
    func cancel()
}

/// One run of the minute-long derivation, on a thread of its own, with Argon2's 1 GiB in an
/// anonymous mapping that exists only while it runs.
final class Derivation: KeyDerivation, @unchecked Sendable {
    enum Failure: Error { case memory }

    private let lock = NSLock()
    private var cancelled = false
    /// One derivation per process, so two 1 GiB mappings never coexist.
    private static let processLock = NSLock()

    func cancel() { lock.withLock { cancelled = true } }

    private var isCancelled: Bool { lock.withLock { cancelled } }

    /// [progress] and [completion] are called on the main queue.
    func start(
        email: String,
        secret: String,
        domain: [UInt8],
        progress: @escaping @Sendable (_ done: Int, _ total: Int, _ elapsed: TimeInterval) -> Void,
        completion: @escaping @Sendable (Result<[UInt8], Error>) -> Void
    ) {
        let thread = Thread { [self] in
            let result = Result {
                try Derivation.processLock.withLock {
                    let start = Date()
                    return try Derivation.withMemory(Keyper.memoryKiB * 1024) { memory in
                        try Keyper.deriveKey(
                            email: email, secret: secret, domain: domain, memory: memory,
                            progress: { done, total in
                                let elapsed = Date().timeIntervalSince(start)
                                DispatchQueue.main.async { progress(done, total, elapsed) }
                            },
                            isCancelled: { self.isCancelled }
                        )
                    }
                }
            }
            DispatchQueue.main.async { completion(result) }
        }
        thread.name = "keyper-derive"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    /// Maps the working memory and unmaps it afterwards, refusing up front when iOS would rather
    /// terminate the app than grant it: a refusal can be shown, a termination cannot.
    static func withMemory<T>(_ bytes: Int, _ body: (UnsafeMutableRawBufferPointer) throws -> T) throws -> T {
        // Zero means no limit applies (the simulator); a phone reports what is left before iOS steps in.
        let available = os_proc_available_memory()
        if available != 0 && available < bytes + 64 << 20 { throw Failure.memory }
        guard let address = mmap(nil, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0), address != MAP_FAILED else {
            throw Failure.memory
        }
        defer { munmap(address, bytes) }
        return try body(UnsafeMutableRawBufferPointer(start: address, count: bytes))
    }
}

#if DEBUG
/// Debug builds only, for UI tests (`-KeyperFakeDerivation`): an instant, deterministic stand-in for
/// the 1 GiB Argon2id run, so that tests about the clipboard, the drill, the gate or the shield do
/// not each spend a minute deriving. The stand-in key is SHA-256 of a label and the normalised
/// inputs: the same inputs give the same phrase, other inputs another. It is not Keyper's key; the
/// one UI test that compares the phrase with the reference runs the real derivation.
final class InstantDerivation: KeyDerivation, @unchecked Sendable {
    static let argument = "-KeyperFakeDerivation"

    func start(
        email: String,
        secret: String,
        domain: [UInt8],
        progress: @escaping @Sendable (_ done: Int, _ total: Int, _ elapsed: TimeInterval) -> Void,
        completion: @escaping @Sendable (Result<[UInt8], Error>) -> Void
    ) {
        let text = "keyper-ui-test-stand-in\n" + Keyper.normalizeEmail(email) + "\n" + Keyper.normalizeSecret(secret)
        let key = Array(SHA256.hash(data: Array(text.utf8)))
        // On the main queue, as the real derivation reports, and after start returns.
        DispatchQueue.main.async {
            progress(1, 1, 0)
            completion(.success(key))
        }
    }

    /// A stopped run's completion is ignored by the model, as for the real derivation.
    func cancel() {}
}

/// Debug builds only: `-KeyperBench` runs SPEC's first vector with the app's own memory mapping and
/// prints the time, for phones (`xcrun devicectl device process launch --console ... -KeyperBench`).
enum DeviceBench {
    /// Standard error is unbuffered, so each line reaches the console at once.
    private static func report(_ line: String) { fputs(line + "\n", stderr) }

    @MainActor
    static func runIfRequested() {
        if ProcessInfo.processInfo.arguments.contains("-KeyperInterfaces") { printInterfaces() }
        guard ProcessInfo.processInfo.arguments.contains("-KeyperBench") else { return }
        UIApplication.shared.isIdleTimerDisabled = true // a sleeping screen suspends the app
        Thread.detachNewThread { @Sendable in run() }
    }

    /// `-KeyperInterfaces`: every interface with its addresses, and what the offline gate makes of them.
    private static func printInterfaces() {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return }
        defer { freeifaddrs(head) }
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let address = entry.pointee.ifa_addr else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let flags = Int32(entry.pointee.ifa_flags)
            report("KEYPER-IF \(String(cString: entry.pointee.ifa_name)) family=\(address.pointee.sa_family) up=\(flags & IFF_UP != 0) running=\(flags & IFF_RUNNING != 0) \(String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self))")
        }
        report("KEYPER-IF gate: \(OfflineMonitor.interfaces())")
    }

    /// On a thread of its own, never the main one.
    private nonisolated static func run() {
        let domain = (0..<32).map { UInt8($0) }
        let expected = "127ed582829bb66d20e2a075c691722dbd582ec8cd4dc7c783cdff609f636a2d"
        for run in 1...3 {
            let start = Date()
            do {
                let key = try Derivation.withMemory(Keyper.memoryKiB * 1024) { memory in
                    try Keyper.deriveKey(email: "alice@example.com", secret: "correct horse battery staple", domain: domain, memory: memory)
                }
                let hex = key.map { String(format: "%02x", $0) }.joined()
                report(String(format: "KEYPER-BENCH run %d: %.1f s, %@", run, Date().timeIntervalSince(start), hex == expected ? "K matches SPEC" : "K MISMATCH \(hex)"))
            } catch {
                report("KEYPER-BENCH run \(run) failed: \(error)")
            }
        }
    }
}
#endif
