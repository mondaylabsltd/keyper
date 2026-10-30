import Testing
@testable import Keyper

/// The UI tests' stand-in for the derivation (Debug only, `-KeyperFakeDerivation`): instant, and
/// deterministic in the normalised inputs, as the drill and the clipboard tests rely on.
@MainActor @Suite
struct InstantDerivationTests {
    private func phrase(_ email: String, _ secret: String) async throws -> [String]? {
        let radios = FakeRadios()
        let model = KeyperModel(monitor: OfflineMonitor(probe: { radios.now }), derivation: { InstantDerivation() })
        model.email = email
        model.secret = secret
        model.generate()
        try await spin(0.2)
        #expect(!model.busy)
        return model.phrase
    }

    @Test func itIsInstantAndFollowsTheNormalisedInputs() async throws {
        let first = try #require(try await phrase(Harness.email, Harness.sentence), "no phrase from the stand-in")
        #expect(try await phrase("Alice@Example.COM", Harness.sentence) == first, "capitals in the email changed the phrase")
        #expect(try await phrase(Harness.email, Harness.sentence + ".") != first, "another sentence gave the same phrase")
        #expect(try await phrase("bob@example.com", Harness.sentence) != first, "another email gave the same phrase")
        // Not the real phrase for these inputs: the stand-in can never pass for Keyper's key.
        #expect(first.joined(separator: " ") != "image ripple naive snake outside leave crunch quality patrol smile goose climb")
    }
}
