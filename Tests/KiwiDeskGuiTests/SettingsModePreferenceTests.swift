import Foundation
import Testing

@testable import KiwiDesk

/// The Simple/Nerd pick's storage (#678 turn 9) — the
/// `AppearancePreference` contract: absent and unrecognised
/// read as the approachable default, and the default leaves no
/// key behind. Scratch domains on both sides (tests.md:
/// process-global state).
@Suite("Settings mode preference")
struct SettingsModePreferenceTests {
    private func scratch() -> UserDefaults {
        let name = "settings-mode-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("absent reads as Simple")
    func absentIsSimple() {
        #expect(
            SettingsModePreference.read(from: scratch())
                == .simple
        )
    }

    @Test("an unrecognised value reads as Simple")
    func unknownIsSimple() {
        let defaults = scratch()
        defaults.set(
            "expert",
            forKey: SettingsModePreference.key
        )
        #expect(
            SettingsModePreference.read(from: defaults)
                == .simple
        )
    }

    @Test("Nerd round-trips")
    func nerdRoundTrips() {
        let defaults = scratch()
        SettingsModePreference.write(.nerd, to: defaults)
        #expect(
            SettingsModePreference.read(from: defaults)
                == .nerd
        )
    }

    @Test("Simple removes the key entirely")
    func simpleLeavesNoTrace() {
        let defaults = scratch()
        SettingsModePreference.write(.nerd, to: defaults)
        SettingsModePreference.write(.simple, to: defaults)
        #expect(
            defaults.string(
                forKey: SettingsModePreference.key
            ) == nil
        )
    }
}
