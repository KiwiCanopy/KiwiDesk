import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The searchable app picker (#263): the substring filter and
/// the icon cache's bundle-id keying. The view itself is left to
/// manual passes; these pin the two pieces of logic behind it.
@MainActor
struct AppPickerTests {
    private func app(
        _ id: String,
        _ name: String
    ) -> KeybindingCatalog.InstalledApp {
        .init(bundleID: id, name: name)
    }

    private var sample: [KeybindingCatalog.InstalledApp] {
        [
            app("com.google.chrome", "Google Chrome"),
            app("com.apple.safari", "Safari"),
            app("com.apple.finder", "Finder"),
        ]
    }

    @Test func emptyQueryKeepsEveryApp() {
        #expect(
            AppPickerFilter.matching(sample, query: "").count == 3
        )
        #expect(
            AppPickerFilter.matching(sample, query: "   ").count
                == 3
        )
    }

    @Test func filterIsSubstringNotPrefix() {
        // "chrome" reaches "Google Chrome" — the whole point
        // over a native menu's prefix type-to-select.
        let hits = AppPickerFilter.matching(
            sample,
            query: "chrome"
        )
        #expect(hits.map(\.bundleID) == ["com.google.chrome"])
    }

    @Test func filterIsCaseInsensitive() {
        let hits = AppPickerFilter.matching(
            sample,
            query: "SAFARI"
        )
        #expect(hits.map(\.bundleID) == ["com.apple.safari"])
    }

    @Test func filterTrimsQuery() {
        let hits = AppPickerFilter.matching(
            sample,
            query: "  finder  "
        )
        #expect(hits.map(\.bundleID) == ["com.apple.finder"])
    }

    @Test func noMatchYieldsEmpty() {
        #expect(
            AppPickerFilter.matching(
                sample,
                query: "nonesuch"
            ).isEmpty
        )
    }

    @Test func filterAlsoMatchesBundleID() {
        // Keeps an app findable by its English/habitual name via
        // the bundle id even when the shown name is localized —
        // "chrome" reaches com.google.chrome.
        let hits = AppPickerFilter.matching(
            [
                app("com.google.chrome", "Chrome-Localized"),
                app("com.apple.safari", "Safari"),
            ],
            query: "chrome"
        )
        #expect(hits.map(\.bundleID) == ["com.google.chrome"])
    }

    @Test func iconCacheKeysCaseInsensitively() {
        // Same bundle id in two cases must hit one memo slot —
        // the identity contract the cache is keyed on (#266).
        let cache = AppIconCache.shared
        let lower = cache.icon(forBundleID: "com.apple.finder")
        let mixed = cache.icon(forBundleID: "Com.Apple.Finder")
        #expect(lower === mixed)
    }

    @Test func iconCacheMemoizesRepeatLookups() {
        let cache = AppIconCache.shared
        let first = cache.icon(forBundleID: "com.example.absent")
        let second = cache.icon(forBundleID: "com.example.absent")
        #expect(first === second)
    }
}
