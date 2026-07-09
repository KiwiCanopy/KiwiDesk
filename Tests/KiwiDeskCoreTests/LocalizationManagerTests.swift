import Foundation
import Testing

@testable import KiwiDeskCore

/// `LocalizationManager` is a process-wide singleton (issue
/// #9); `.serialized` keeps these tests from racing each other
/// through `select(_:)`, and every test restores "System
/// default" afterward so later suites see a clean slate.
@Suite("LocalizationManager", .serialized)
@MainActor
struct LocalizationManagerTests {
    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    @Test("a missing key falls back to the English argument")
    func missingKeyFallsBackToEnglish() {
        reset()
        let value = L(
            "a_key_no_locale_will_ever_define",
            "The English fallback"
        )
        #expect(value == "The English fallback")
    }

    @Test("the seeded German locale is discovered and shipped")
    func germanLocaleIsAvailable() {
        #expect(LocalizationManager.shared.available.contains("de"))
        // English is inline at call sites, never a bundled
        // locale file the manager loads.
        #expect(!LocalizationManager.shared.available.contains("en"))
    }

    @Test("selecting a shipped locale returns its translation")
    func explicitSelectionTranslates() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        // Seeded in the small de.json (docs/translating.md).
        let value = L("menu.quit", "Quit KiwiDesk")
        #expect(value == "KiwiDesk beenden")
    }

    @Test(
        "an untranslated key falls back to English (per-key)"
    )
    func perKeyFallbackWithinASelectedLocale() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        // Not present in the small German seed — must fall
        // back to the English argument, not an empty string or
        // a crash.
        let value = L(
            "a_key_the_german_seed_does_not_translate",
            "Untranslated fallback"
        )
        #expect(value == "Untranslated fallback")
    }

    @Test("nil selection resolves to system-or-English")
    func nilSelectionResolvesSystemOrEnglish() {
        reset()
        // Without a matching shipped locale for the test
        // runner's system language (almost certainly not
        // "de" or an unshipped code), English is used.
        let value = L("menu.quit", "Quit KiwiDesk")
        #expect(!value.isEmpty)
    }

    @Test("select(nil) restores System default")
    func selectNilRestoresSystemDefault() {
        LocalizationManager.shared.select("de")
        LocalizationManager.shared.select(nil)
        #expect(LocalizationManager.shared.selection == nil)
    }

    @Test("adoptPersistedSelection injects a startup pick")
    func adoptPersistedSelectionInjectsPick() {
        LocalizationManager.shared.adoptPersistedSelection("de")
        defer { reset() }
        #expect(LocalizationManager.shared.selection == "de")
        #expect(L("menu.quit", "Quit KiwiDesk") == "KiwiDesk beenden")
    }

    @Test("an unshipped explicit selection falls back to English")
    func unshippedSelectionFallsBackToEnglish() {
        reset()
        LocalizationManager.shared.select("xx-not-a-real-locale")
        defer { reset() }
        let value = L("menu.quit", "Quit KiwiDesk")
        #expect(value == "Quit KiwiDesk")
    }

    // MARK: - Interpolation overload (issue #9 review)

    @Test("the interpolating overload fills English positionally")
    func interpolatingOverloadFillsEnglish() {
        reset()
        let value = L(
            "a_key_no_locale_will_ever_define_interp",
            "Move to %1$@",
            "Studio"
        )
        #expect(value == "Move to Studio")
    }

    @Test("the interpolating overload resolves through a translation")
    func interpolatingOverloadUsesTranslation() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        // Seeded in de.json: the placeholder moves relative to
        // the English word order — exactly the point of
        // positional (not bare %@) specifiers.
        let value = L(
            "monitor_chip.move_to",
            "Move to %1$@",
            "Studio"
        )
        #expect(value == "Nach Studio verschieben")
    }

    @Test("an untranslated interpolating key falls back to English")
    func interpolatingOverloadPerKeyFallback() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        let value = L(
            "a_key_the_german_seed_does_not_translate_interp",
            "Space %1$d: %2$@",
            3,
            "Monocle"
        )
        #expect(value == "Space 3: Monocle")
    }
}
