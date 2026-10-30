import Foundation
import Testing
import UIKit
@testable import Keyper

extension KeyperClaims {
    /// Claim 3, "Nothing stored": nothing typed is written to storage, and leaving the app wipes the
    /// sentence and the phrase (the email stays, by design).
    @MainActor @Suite
    struct NothingStoredTests {
        @Test func leavingWipesTheSentenceAndThePhraseAndKeepsTheEmail() {
            let h = Harness()
            h.generated()
            h.model.revealed = true
            h.model.focus = .email

            h.model.leave()

            #expect(h.model.secret.isEmpty, "the sentence is wiped")
            #expect(h.model.phrase == nil, "the phrase is wiped")
            #expect(!h.model.showsResult)
            #expect(!h.model.revealed, "the sentence is masked again")
            #expect(h.model.focus == nil)
            #expect(h.model.email == Harness.email, "the email is kept")
        }

        /// Leaving the app from the drill page wipes what was typed there and the phrase kept behind
        /// it, and closes the page; the first entry's email stays, as it always does.
        @Test func leavingDuringTheDrillWipesItAndThePhraseKeptForIt() {
            let h = Harness()
            h.generated()
            h.model.startDrill()
            h.type(Harness.email, into: .drillEmail)
            h.type("In 2009", into: .drillSecret)
            h.model.drillRevealed = true
            h.model.leave()
            #expect(!h.model.drilling, "the drill page stayed open")
            #expect(h.model.drillEmail.isEmpty && h.model.drillSecret.isEmpty && !h.model.drillRevealed)
            #expect(h.model.drillResult == nil)
            #expect(h.model.phrase == nil)
            #expect(h.model.secret.isEmpty)
            #expect(h.model.email == Harness.email)
            h.model.secret = Harness.sentence
            h.model.generate() // a fresh derivation, not the old phrase
            #expect(h.derivations.runs.count == 2)
            #expect(!h.model.showsResult)
        }

        @Test func leavingDuringADerivationStopsItAndDropsItsResult() {
            let h = Harness()
            h.model.email = Harness.email
            h.model.secret = Harness.sentence
            h.model.generate()
            h.model.leave()
            let run = h.derivations.runs[0]
            #expect(run.cancelled)
            #expect(!h.model.busy)
            run.finish()
            #expect(h.model.phrase == nil)
        }

        /// The running app asks for no state restoration: its scene keeps no activity of its own, and
        /// the only restoration data, which SwiftUI writes for every WindowGroup, names the scene and
        /// holds nothing else.
        @Test func theSceneKeepsNoState() throws {
            let scene = hostScene
            #expect(scene.userActivity == nil)
            if let activity = scene.session.stateRestorationActivity {
                let keys = Set((activity.userInfo ?? [:]).keys.map { "\($0)" })
                #expect(keys.isSubset(of: ["com.apple.SwiftUI.sceneID"]), "restoration data: \(keys)")
            }
            var controllers = scene.windows.compactMap(\.rootViewController)
            while let controller = controllers.popLast() {
                #expect(controller.restorationIdentifier == nil, "\(type(of: controller)) asks for restoration")
                controllers += controller.children
            }
        }

        /// The app's code uses no storage API at all; the one UserDefaults write is the language,
        /// the same per-app setting Settings → Keyper → Language writes.
        @Test(.enabled(if: canReadTheMacsFiles, "reads the app's sources from the Mac"))
        func theCodeCallsNoStorage() throws {
            let banned = [
                "@SceneStorage", "@AppStorage", "UserDefaults", "NSUbiquitousKeyValueStore", "restorationIdentifier",
                "stateRestorationActivity", "NSUserActivity", "userActivity", "FileManager", "write(to", "write(toFile",
                "createFile", "fopen", "NSKeyedArchiver", "SecItemAdd", "SecItemUpdate", "Keychain", "CoreData",
                "SwiftData", "NSPersistentContainer", "sqlite", "URLSession", "URLCache", "HTTPCookieStorage", "os_log",
                "Logger(", "NSLog", "print(",
            ]
            let files = try FileManager.default.contentsOfDirectory(at: appSources, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
            #expect(files.count >= 10)
            for file in files {
                let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
                for (n, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    for word in banned where Self.uses(line, word) {
                        let allowed = file.lastPathComponent == "L10n.swift" && line.contains("UserDefaults.standard.set([rawValue], forKey: \"AppleLanguages\")")
                        #expect(allowed, "\(file.lastPathComponent):\(n + 1) uses \(word)")
                    }
                }
            }
        }

        private static func size(_ url: URL) -> Int {
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
        }

        /// `word` in `line`, not as the tail of a longer name (`fingerprint(` is not `print(`).
        private static func uses(_ line: String, _ word: String) -> Bool {
            var rest = line[...]
            while let range = rest.range(of: word) {
                let before = rest[..<range.lowerBound].last
                if !(word.first!.isLetter && (before?.isLetter == true || before?.isNumber == true || before == "_")) { return true }
                rest = rest[range.upperBound...]
            }
            return false
        }

        /// One real derivation in the running app (the same 1 GiB Argon2id run as the app's), then the
        /// app's container: Documents, Application Support and tmp hold nothing; Caches holds only
        /// iOS's own (com.apple.*, such as Metal's shader cache); the rest is iOS's bookkeeping
        /// (Preferences, Saved Application State, SplashBoard, SystemData); no file anywhere holds the
        /// email, the sentence or the phrase; and the app's defaults hold only iOS's own keys.
        @Test(.timeLimit(.minutes(10)))
        func aRealDerivationLeavesNothingInTheContainer() async throws {
            let radios = FakeRadios()
            let model = KeyperModel(monitor: OfflineMonitor(probe: { radios.now })) // the real Derivation
            model.email = Harness.email
            model.secret = Harness.sentence
            let start = Date()
            model.generate()
            #expect(model.busy)
            while model.busy { try await spin(0.5) }
            let phrase = try #require(model.phrase, "no phrase: \(model.errorMessage ?? "")")
            // The phrase of reference/keyper.py and the Android app for these inputs and this domain.
            #expect(phrase.joined(separator: " ") == "image ripple naive snake outside leave crunch quality patrol smile goose climb")
            print(String(format: "KEYPER derivation in a unit test: %.1f s", Date().timeIntervalSince(start)))
            UserDefaults.standard.synchronize()

            let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath()
            let files = (FileManager.default.subpaths(atPath: home.path) ?? []).filter { path in
                var directory: ObjCBool = false
                return FileManager.default.fileExists(atPath: home.appendingPathComponent(path).path, isDirectory: &directory) && !directory.boolValue
            }
            for path in files {
                let parts = path.split(separator: "/").map(String.init)
                let iOSOwn = path == ".com.apple.mobile_container_manager.metadata.plist"
                    || path == "Library/Preferences/\(Bundle.main.bundleIdentifier!).plist"
                    || path.hasPrefix("Library/Saved Application State/")
                    || path.hasPrefix("Library/SplashBoard/")
                    || path.hasPrefix("SystemData/")
                    || (path.hasPrefix("tmp/.com.apple.Pasteboard.") && Self.size(home.appendingPathComponent(path)) == 0)
                    || (path.hasPrefix("Library/Caches/") && parts.dropFirst(2).contains { $0.hasPrefix("com.apple.") })
                #expect(iOSOwn, "the app wrote \(path)")
            }
            // tmp may hold only UIKit's empty placeholders, one per pasteboard write (the clipboard tests').
            for directory in ["Documents", "Library/Application Support", "tmp"] {
                let held = files.filter { $0.hasPrefix(directory + "/") && Self.size(home.appendingPathComponent($0)) != 0 }
                #expect(held.isEmpty, "\(directory) holds \(held)")
            }

            let needles = [Harness.email, Harness.sentence, phrase.joined(separator: " "), phrase.prefix(3).joined(separator: " ")]
                .flatMap { [Data($0.utf8), $0.data(using: .utf16LittleEndian)!, $0.data(using: .utf16BigEndian)!] }
            var scanned = 0
            for path in files {
                guard let data = try? Data(contentsOf: home.appendingPathComponent(path), options: .mappedIfSafe), data.count < 64 << 20 else { continue }
                scanned += 1
                for needle in needles {
                    #expect(data.range(of: needle) == nil, "\(path) holds what was typed or the phrase")
                }
            }
            #expect(scanned > 0)

            let defaults = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier!) ?? [:]
            for (key, value) in defaults {
                #expect(key == "AppleLanguages" || key.hasPrefix("NS") || key.hasPrefix("Apple") || key.hasPrefix("com.apple."), "defaults key \(key)")
                let text = "\(value)"
                for secret in [Harness.email, Harness.sentence] + phrase {
                    #expect(!text.contains(secret), "defaults \(key) holds \(secret)")
                }
            }
            model.leave()
        }
    }
}
