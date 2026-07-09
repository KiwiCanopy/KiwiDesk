import Foundation
import Testing

@testable import KiwiDeskCore

/// Pins the language pick's storage contract (issue #9): app
/// preferences (`UserDefaults`), not `gui.json` — writing a
/// language must never create or touch a sidecar. Uses a
/// throwaway, suite-scoped `UserDefaults` domain so these tests
/// can't pollute (or be polluted by) the real app preferences.
@Suite("LocalizationPreference (UserDefaults)")
struct LocalizationPreferenceTests {
    private func makeDefaults() -> (
        defaults: UserDefaults, cleanup: () -> Void
    ) {
        let domain = "kiwi-locale-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        return (
            defaults,
            { defaults.removePersistentDomain(forName: domain) }
        )
    }

    @Test("an absent key reads back as nil (System default)")
    func absentKeyReadsNil() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        #expect(LocalizationPreference.read(from: defaults) == nil)
    }

    @Test("write then read round-trips an explicit language")
    func writeThenReadRoundTrips() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        LocalizationPreference.write("de", to: defaults)
        #expect(LocalizationPreference.read(from: defaults) == "de")
    }

    @Test("writing nil removes the key (back to System default)")
    func writingNilRemovesKey() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        LocalizationPreference.write("de", to: defaults)
        LocalizationPreference.write(nil, to: defaults)
        #expect(LocalizationPreference.read(from: defaults) == nil)
        #expect(
            defaults.object(forKey: LocalizationPreference.key)
                == nil
        )
    }

    @Test("the storage key matches the documented contract")
    func storageKeyIsStable() {
        // Pinned: changing this key would silently reset every
        // existing user's language pick back to System default.
        #expect(LocalizationPreference.key == "language")
    }
}
