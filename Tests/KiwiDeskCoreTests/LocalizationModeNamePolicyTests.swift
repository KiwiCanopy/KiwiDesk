import Foundation
import Testing

/// Pins **which locales render the layout mode names natively**,
/// against the shipped catalogs.
///
/// The policy: mode names stay English wherever the alphabet
/// allows, because they are values the user types verbatim —
/// `KiwiDesk.set_mode(1, "stack")` in Lua, `{"command":
/// "set_mode","args":["1","grid"]}` over IPC. A picker reading
/// "Pila" above a config that only accepts `"stack"` breaks the
/// link between what you see and what you write, and no other
/// setting has that property. The three CJK locales are the
/// exception: there the English word is a foreign body in a way it
/// is not between two Latin-script languages.
///
/// This is the one suite here that reads the real catalogs, and
/// deliberately so. The guard suites must not — asserting a
/// *predicate* against the corpus makes its coverage depend on the
/// corpus staying dirty. This asserts a *policy*: the shipped
/// files still match a decision that prose in four files describes.
/// Without it those descriptions are unfalsifiable, and the last
/// count stated in prose was wrong in every place it appeared.
///
/// See `docs/localization-naming.md`.
@Suite("localization mode-name policy")
struct LocalizationModeNamePolicyTests {
    private static let nativeLocales: Set<String> = [
        "ja", "ko", "zh-Hans",
    ]

    private static let modeKeys = [
        "layout.floating.name",
        "layout.grid.name",
        "layout.monocle.name",
        "layout.scrolling.name",
        "layout.stack.name",
        "layout.track.name",
    ]

    /// The shipped catalogs, reached the way every corpus-reading
    /// suite here does: relative to `#filePath`, so the test moves
    /// with the checkout.
    private static var localesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
    }

    private func catalog(
        _ locale: String
    ) throws -> [String: String] {
        let url = Self.localesDirectory
            .appendingPathComponent("\(locale).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(
            [String: String].self,
            from: data
        )
    }

    /// Mirrors `shipped_locale_files()`, `missing_` filter
    /// included — deliberate residue, not an assumption that a
    /// worksheet could be here. It cannot
    /// (`scripts/locale_paths.py`), and `extract-keys --check`
    /// owns naming one that is.
    private func shippedLocaleCodes() throws -> [String] {
        try FileManager.default
            .contentsOfDirectory(
                at: Self.localesDirectory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { !$0.hasPrefix("missing_") }
            .sorted()
    }

    @Test("only the CJK locales render mode names natively")
    func nativeLocalesAreExactlyTheCJKThree() throws {
        let english = try catalog("en")
        var native: Set<String> = []
        for locale in try shippedLocaleCodes() where locale != "en" {
            let catalog = try self.catalog(locale)
            let differs = Self.modeKeys.contains { key in
                guard let mine = catalog[key],
                    let source = english[key]
                else { return false }
                return mine != source
            }
            if differs { native.insert(locale) }
        }
        #expect(native == Self.nativeLocales)
    }

    /// A locale on the English side keeps **every** mode name, not
    /// most of them. A half-translated picker is the state the
    /// prose/picker guard cannot see — it would skip the modes the
    /// locale left English and police only the rest.
    @Test("an English-side locale keeps every mode name")
    func englishSideLocalesAreComplete() throws {
        let english = try catalog("en")
        for locale in try shippedLocaleCodes()
        where locale != "en" && !Self.nativeLocales.contains(locale) {
            let catalog = try self.catalog(locale)
            for key in Self.modeKeys {
                #expect(
                    catalog[key] == english[key],
                    "\(locale) translated \(key)"
                )
            }
        }
    }

    /// And the mirror: a CJK locale renders every one of them, so
    /// the guard covers its whole picker rather than a subset.
    @Test("a native-side locale renders every mode name")
    func nativeSideLocalesAreComplete() throws {
        let english = try catalog("en")
        for locale in Self.nativeLocales.sorted() {
            let catalog = try self.catalog(locale)
            for key in Self.modeKeys {
                #expect(
                    catalog[key] != english[key],
                    "\(locale) left \(key) in English"
                )
            }
        }
    }
}
