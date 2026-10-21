// swift-tools-version: 6.0
// Keyper's protocol core for iOS: pure Swift on the system CryptoKit, no other dependencies.
// `swift test -c release` runs everything on the Mac, including SPEC's 1 GiB vectors.
import PackageDescription

let package = Package(
    name: "KeyperCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KeyperCore", targets: ["KeyperCore"])],
    targets: [
        // Optimised in every configuration: unoptimised, a 1 GiB Argon2id takes many minutes, which
        // would make Debug builds of the app unusable.
        .target(name: "KeyperCore", swiftSettings: [.unsafeFlags(["-O"])]),
        .testTarget(name: "KeyperCoreTests", dependencies: ["KeyperCore"]),
    ]
)
