import Foundation
import KeyperCore
import Testing
@testable import Keyper

/// The repository root, for the fixtures shared with the Android app (the simulator reads the Mac's files).
private let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

private func fixture(_ name: String) throws -> [[String]] {
    try String(contentsOf: repository.appendingPathComponent("test-vectors/\(name)"), encoding: .utf8)
        .split(separator: "\n").filter { !$0.hasPrefix("#") }
        .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
}

struct L10nTests {
    /// ICU's own output (libicucore, skeleton "compact-long"), which Android's CompactDecimalFormat produces.
    @Test(.enabled(if: canReadTheMacsFiles, "reads test-vectors/ from the Mac")) func compactMatchesICU() throws {
        let rows = try fixture("compact.tsv")
        #expect(rows.count > 40)
        for row in rows {
            let x = Double(row[0])!
            #expect(L10n(.en).compact(x) == row[1], "en \(row[0])")
            #expect(L10n(.zh).compact(x) == row[2], "zh \(row[0])")
        }
    }

    /// What the Android app shows for the same sentences (seen on the emulator).
    @Test(arguments: [
        ("In 2009 Grandma Li and I picked 7 green date", Language.en, "Good · 44 characters", "A thousand GPUs: about 61 thousand years and US$21 billion of electricity"),
        ("In 2009 Grandma Li and I picked 7 green dates", Language.en, "Good · 45 characters", "A thousand GPUs: about 171 thousand years and US$60 billion of electricity"),
        ("In 2009 Grandma Li and I picked 7 green date", Language.zh, "较强 · 44 个字符", "一千张显卡破解约 6.1万年，电费约 212亿美元"),
        ("In 2009 Grandma Li and I picked 7 green dates", Language.zh, "较强 · 45 个字符", "一千张显卡破解约 17万年，电费约 600亿美元"),
    ])
    func strengthTextsMatchAndroid(secret: String, language: Language, summary: String, crack: String) {
        let s = L10n(language)
        let estimate = Strength.of(secret)
        #expect(s.format("strength_summary", s["level_good"], Keyper.normalizeSecret(secret).count) == summary)
        #expect(s.format("crack_time", s.duration(estimate.crackSeconds(gpus: 1000)), s.money(estimate.crackDollars())) == crack)
    }

    @Test func durations() {
        let en = L10n(.en)
        #expect(en.duration(0.5) == "under a second")
        #expect(en.duration(1) == "1 second")
        #expect(en.duration(59) == "59 seconds")
        #expect(en.duration(3600 * 7.5) == "7 hours")
        #expect(en.duration(86400 * 320) == "320 days")
        #expect(en.duration(365.25 * 86400 * 890) == "890 years")
        #expect(en.duration(1e20) == "longer than the age of the universe")
        #expect(L10n(.zh).duration(365.25 * 86400 * 1) == "1 年")
        #expect(en.money(0.5) == "under US$1")
        #expect(en.money(1e15) == "more than the world's yearly GDP")
    }

    /// Both apps must derive the same phrases, so they must carry the same domain constant.
    @Test(.enabled(if: canReadTheMacsFiles, "reads the Android sources from the Mac")) func domainMatchesTheAndroidApp() throws {
        let kotlin = try String(contentsOf: repository.appendingPathComponent("app-android/app/src/main/kotlin/app/getkeyper/Domain.kt"), encoding: .utf8)
        #expect(kotlin.contains("\"\(domainHex)\""), "Domain.swift and Domain.kt differ")
        #expect(Keyper.domainId(domainHex.unhex) == "A248-7EAB", "The domain constant changed: every user's phrase would change (SPEC.md)")
    }
}
