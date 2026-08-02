import Foundation
import Testing

@testable import KiwiDeskCore

/// The packaged `.app` must tell macOS which languages it
/// speaks, and must derive that list from the shipped catalogs
/// rather than carry a typed copy of them.
///
/// The failure this guards is silent in a way the language
/// picker cannot show: with no `CFBundleLocalizations`, macOS
/// resolves the process locale to `CFBundleDevelopmentRegion`,
/// so "System default" answers English on a German Mac and every
/// catalog in `Resources/Locales` becomes unreachable except by
/// picking it by hand. Nothing crashes and nothing logs — the
/// app is simply monolingual for anyone who never opens
/// Settings.
@Suite("App plist localizations")
struct AppPlistLocalizationTests {
    private static var buildScript: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("scripts")
            .appendingPathComponent("build-app.sh")
    }

    private func source() throws -> String {
        try String(
            contentsOf: Self.buildScript,
            encoding: .utf8
        )
    }

    /// The array's contents, between its own `<array>` tags.
    private func localizationsArray() throws -> String {
        let script = try source()
        let key = try #require(
            script.range(of: "<key>CFBundleLocalizations</key>"),
            "the plist declares no CFBundleLocalizations"
        )
        let tail = key.upperBound..<script.endIndex
        let open = try #require(
            script.range(of: "<array>", range: tail),
            "CFBundleLocalizations is not followed by an array"
        )
        let rest = open.upperBound..<script.endIndex
        let close = try #require(
            script.range(of: "</array>", range: rest),
            "the CFBundleLocalizations array is never closed"
        )
        return String(script[open.upperBound..<close.lowerBound])
    }

    @Test("The plist declares the languages the app speaks")
    func declaresLocalizations() throws {
        _ = try localizationsArray()
    }

    /// The array may hold the expansion and nothing else. A
    /// hand-typed `<string>de</string>` is the drift the
    /// derivation exists to prevent — it would pass a "contains
    /// the key" check while going stale the next time a locale
    /// is added or dropped.
    @Test("The locale list is derived, never typed out")
    func derivesRatherThanTypes() throws {
        let residue = try localizationsArray()
            .replacingOccurrences(of: "$LOCALE_KEYS", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(residue.isEmpty)
    }

    /// And it must derive from the same directory `LocaleCatalog`
    /// reads at runtime, so the bundle's claim and the app's
    /// behavior cannot disagree.
    @Test("The derivation globs the shipped catalog directory")
    func readsTheCatalogDirectory() throws {
        let script = try source()
        #expect(
            script.contains(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        )
        #expect(script.contains("\"$LOCALES\"/*.json"))
    }
}
