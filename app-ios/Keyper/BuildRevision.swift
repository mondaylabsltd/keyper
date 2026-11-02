import Foundation

/// Written into the bundle at build time, never read from the user's filesystem.
enum BuildRevision {
    static let current: String = {
        guard let url = Bundle.main.url(forResource: "BuildRevision", withExtension: "txt"),
              let revision = try? String(contentsOf: url, encoding: .utf8) else { return "unknown" }
        return revision.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
}
