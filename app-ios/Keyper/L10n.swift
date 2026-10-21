import Foundation

/// The app's two languages. The pill in the header switches between them in place, as on Android.
enum Language: String, CaseIterable, Sendable {
    case en
    case zh = "zh-Hans"

    var other: Language { self == .en ? .zh : .en }

    /// The language iOS chose for the app (Settings → Keyper → Language, else the device's).
    static var preferred: Language {
        Bundle.main.preferredLocalizations.first.map { $0.hasPrefix("zh") ? .zh : .en } ?? .en
    }

    /// Lets iOS remember the choice for the next launch, through the same per-app language setting
    /// that Settings → Keyper → Language writes. Keyper itself stores nothing.
    func makePreferred() {
        UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
    }
}

/// Strings of one language, read from its .lproj, so the screen can switch language without a restart.
struct L10n: Sendable {
    let language: Language
    private let bundle: Bundle

    init(_ language: Language) {
        self.language = language
        bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    subscript(_ key: String) -> String { bundle.localizedString(forKey: key, value: key, table: nil) }

    func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: self[key], locale: Locale(identifier: language.rawValue), arguments: args)
    }

    /// English has "one" and "other"; Chinese only "other".
    func plural(_ key: String, _ n: Int) -> String {
        format(language == .en && n == 1 ? "\(key).one" : "\(key).other", n)
    }

    /// How long a thousand GPUs would take, worded as the Android app words it.
    func duration(_ seconds: Double) -> String {
        let years = seconds / (365.25 * 86400)
        if seconds < 1 { return self["under_a_second"] }
        if seconds < 60 { return plural("seconds", Int(seconds)) }
        if seconds < 3600 { return plural("minutes", Int(seconds / 60)) }
        if seconds < 86400 { return plural("hours", Int(seconds / 3600)) }
        if years < 1 { return plural("days", Int(seconds / 86400)) }
        if years < 1000 { return plural("years", Int(years)) }
        if years < 1.38e10 { return format("years_many", compact(years)) }
        return self["beyond_universe"]
    }

    func money(_ dollars: Double) -> String {
        if dollars < 1 { return self["under_a_dollar"] }
        if dollars >= 1e14 { return self["beyond_gdp"] }
        return format("money", compact(dollars))
    }

    /// ICU's long compact notation, as Android's CompactDecimalFormat writes it: "61 thousand",
    /// "6.1万", "212亿". At least two significant digits, otherwise whole numbers, rounding half to
    /// even in decimal, as ICU does on the number's shortest decimal form. Checked against ICU by
    /// L10nTests with test-vectors/compact.tsv.
    func compact(_ x: Double) -> String {
        let units: [(scale: Double, name: String)] = language == .en
            ? [(1e12, " trillion"), (1e9, " billion"), (1e6, " million"), (1e3, " thousand")]
            : [(1e12, "万亿"), (1e8, "亿"), (1e4, "万")]
        let step = Decimal(language == .en ? 1e3 : 1e4)
        let exact = Decimal(string: "\(x)", locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(x)
        var i = units.firstIndex { x >= $0.scale } ?? units.count // units.count: no unit
        var value = significant(i < units.count ? exact / Decimal(units[i].scale) : exact)
        // Rounding up to a whole step moves on to the next unit: 999,999 is "1 million".
        if value >= step && i > 0 {
            i -= 1
            value = significant(exact / Decimal(units[i].scale))
        }
        return "\(value)" + (i < units.count ? units[i].name : "")
    }

    private func significant(_ d: Decimal) -> Decimal {
        var input = d
        var result = Decimal()
        NSDecimalRound(&result, &input, d >= 10 ? 0 : 1, .bankers)
        return result
    }
}
