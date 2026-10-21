import CoreTelephony
import Darwin
import Foundation

/// What the offline gate can see on iOS without asking anything: which network interfaces have an
/// address that reaches beyond the link, and whether a cellular radio is active (airplane mode turns
/// it off). Wi-Fi that is switched on but joined to no network, and Bluetooth, are invisible to apps.
///
/// The interfaces come from getifaddrs, a list the kernel keeps. The Network framework would make
/// iPhones sold in mainland China ask whether Keyper may use wireless data, a question an offline
/// app must never raise; and if the user said no, it would report "no network" with Wi-Fi still on.
@MainActor
final class OfflineMonitor {
    struct Radios: Equatable, Sendable {
        var cellular = false
        var wifi = false
        var otherNetwork = false
        var offline: Bool { !cellular && !wifi && !otherNetwork }
    }

    var onChange: ((Radios) -> Void)?
    private let telephony = CTTelephonyNetworkInfo()
    private var timer: Timer?
    private var last: Radios?

    func start() {
        // Polled, as on Android: neither source announces its changes.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        check()
    }

    func check() {
        #if DEBUG
        // Simulators always share the Mac's network: UI tests can ask for the offline state.
        if ProcessInfo.processInfo.arguments.contains("-KeyperSimulateOffline") {
            report(Radios())
            return
        }
        #endif
        var now = OfflineMonitor.interfaces()
        if !(telephony.serviceCurrentRadioAccessTechnology ?? [:]).isEmpty { now.cellular = true }
        report(now)
    }

    private func report(_ now: Radios) {
        guard now != last else { return }
        last = now
        onChange?(now)
    }

    /// Interfaces that are up with an address beyond the link: en0 is Wi-Fi, pdp_ip* cellular data,
    /// anything else (a USB or Ethernet adapter, a hotspot bridge) another network. Link-local
    /// addresses alone (AirDrop, the USB link to a Mac) reach nothing, and VPN tunnels ride on one
    /// of the others, so neither counts.
    nonisolated static func interfaces() -> Radios {
        var radios = Radios()
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return radios }
        defer { freeifaddrs(head) }
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0,
                  let address = entry.pointee.ifa_addr, reachesBeyondTheLink(address) else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            if name == "en0" {
                radios.wifi = true
            } else if name.hasPrefix("pdp_ip") {
                radios.cellular = true
            } else if !["utun", "ipsec", "awdl", "llw", "anpi", "lo"].contains(where: name.hasPrefix) {
                radios.otherNetwork = true
            }
        }
        return radios
    }

    private nonisolated static func reachesBeyondTheLink(_ address: UnsafeMutablePointer<sockaddr>) -> Bool {
        switch Int32(address.pointee.sa_family) {
        case AF_INET:
            let ip = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            return ip >> 16 != 0xA9FE // 169.254.0.0/16 is link-local
        case AF_INET6:
            let bytes = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr.__u6_addr.__u6_addr8 }
            return !(bytes.0 == 0xFE && bytes.1 & 0xC0 == 0x80) // fe80::/10 is link-local
        default:
            return false
        }
    }
}
