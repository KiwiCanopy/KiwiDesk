import Foundation
import Testing

@testable import KiwiDesk

/// "Use one width for all borders" storage (#754) — the
/// `SettingsModePreference` contract, and the reason it is a
/// preference at all: nothing in `TilingSettings` records the
/// link, so its whole persistence is these four behaviours.
/// Absent reads as LINKED, the approachable default, and
/// re-linking leaves no key behind. Scratch domains on both
/// sides (tests.md: process-global state).
@Suite("Border width link preference")
struct BorderWidthLinkPreferenceTests {
    private func scratch() -> UserDefaults {
        let name = "border-link-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("absent reads as linked")
    func absentIsLinked() {
        #expect(BorderWidthLinkPreference.read(from: scratch()))
    }

    @Test("unlinking round-trips")
    func unlinkedRoundTrips() {
        let defaults = scratch()
        BorderWidthLinkPreference.write(false, to: defaults)
        #expect(
            !BorderWidthLinkPreference.read(from: defaults)
        )
    }

    @Test("re-linking removes the key entirely")
    func linkedLeavesNoTrace() {
        let defaults = scratch()
        BorderWidthLinkPreference.write(false, to: defaults)
        BorderWidthLinkPreference.write(true, to: defaults)
        #expect(
            defaults.object(
                forKey: BorderWidthLinkPreference.key
            ) == nil
        )
        #expect(BorderWidthLinkPreference.read(from: defaults))
    }

    /// The link is a GUI preference, never a config field — so
    /// the key it writes must not be one `TilingSettings`
    /// encodes. A census id colliding with a settings path is
    /// how a "GUI convenience" quietly becomes a fourth axis.
    @Test("the census row is not a settings path")
    func censusRowIsNotASettingsPath() {
        let id = SettingKey.borders(.linkedBorderWidth).id
        #expect(id.hasPrefix("UserDefaults."))
        #expect(!id.hasPrefix("settings."))
    }
}
