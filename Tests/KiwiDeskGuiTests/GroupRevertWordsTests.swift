import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A layer or lens the draft ADDED has nothing saved to put back,
/// so its ↺ question says it removes it rather than "back as it was
/// saved" (owner eyeball, 2026-10-20).
@MainActor
@Suite("A whole-group ↺ says what it does")
struct GroupRevertWordsTests {
    private typealias W = GroupRevertWords

    private func row(_ revert: SettingsRowRevert) -> SettingsDiffRow {
        SettingsDiffRow(
            id: "lens",
            key: .kiwiVision(.lenses),
            label: "Lens",
            revert: revert
        )
    }

    @Test func addedLensIsRemoved() {
        LocalizationManager.shared.select("en")
        let added = row(.lens(stored: nil, page: "abc"))
        #expect(W.title(for: added) == "Remove the “abc” lens?")
        #expect(W.confirm(for: added) == "Remove Lens")
        #expect(!W.message(for: added).contains("saved,"))
    }

    @Test func addedLayerIsRemoved() {
        LocalizationManager.shared.select("en")
        let added = row(.layer(stored: nil, page: "Work"))
        #expect(
            W.title(for: added) == "Remove the “Work” layer?"
        )
        #expect(W.confirm(for: added) == "Remove Layer")
    }

    /// A deleted or renamed one keeps the put-back wording.
    @Test func savedGroupIsReverted() {
        LocalizationManager.shared.select("en")
        let deleted = row(.lens(stored: "test", page: nil))
        let renamed = row(.layer(stored: "Old", page: "New"))
        #expect(
            W.title(for: deleted) == "Revert the “test” lens?"
        )
        #expect(W.confirm(for: deleted) == "Revert Lens")
        #expect(
            W.title(for: renamed) == "Revert the “New” layer?"
        )
    }

    /// A base entry's note names what it is: a shortcut is no rule.
    @Test func newProfilesNoteNamesTheEntry() {
        LocalizationManager.shared.select("en")
        #expect(
            SettingsModel.newProfilesNote(.key, true)
                == "New profiles get this shortcut"
        )
        #expect(
            SettingsModel.newProfilesNote(.key, false)
                == "New profiles won't get this shortcut"
        )
        #expect(
            SettingsModel.newProfilesNote(.float, true)
                == "New profiles get this rule"
        )
        #expect(
            SettingsModel.newProfilesNote(.scroll, false)
                == "New profiles won't get this setting"
        )
    }
}
