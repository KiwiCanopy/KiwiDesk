import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The mode flip's navigation contract (#678 turn 9): Nerd →
/// Simple pops an area the flip removed back to Home (mode
/// gates whole cards — the area ceased to exist, so this is not
/// a grey-don't-hide case), leaves a Simple area alone, and the
/// pick persists through the injected domain.
@MainActor
@Suite("Settings mode navigation")
struct SettingsModeNavigationTests {
    private func model() -> (SettingsModel, UserDefaults) {
        let name = "settings-mode-nav-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (makeTestModel(defaults: defaults), defaults)
    }

    @Test("Nerd → Simple pops a Power-User-only area to Home")
    func flipPopsNerdArea() {
        let (model, _) = model()
        model.setSettingsMode(.powerUser)
        model.destination = .layoutDefaults
        model.setSettingsMode(.simple)
        #expect(model.destination == nil)
    }

    @Test("Nerd → Simple leaves a Simple area alone")
    func flipKeepsSimpleArea() {
        let (model, _) = model()
        model.setSettingsMode(.powerUser)
        model.destination = .gapsAndBorders
        model.setSettingsMode(.simple)
        #expect(model.destination == .gapsAndBorders)
    }

    @Test("Home survives the flip")
    func flipOnHome() {
        let (model, _) = model()
        model.setSettingsMode(.powerUser)
        model.setSettingsMode(.simple)
        #expect(model.destination == nil)
    }

    @Test("the pick persists through the injected domain")
    func flipPersists() {
        let (model, defaults) = model()
        model.setSettingsMode(.powerUser)
        #expect(
            SettingsModePreference.read(from: defaults)
                == .powerUser
        )
        model.setSettingsMode(.simple)
        #expect(
            SettingsModePreference.read(from: defaults)
                == .simple
        )
    }

    /// The count the header chip shows rides the same baselines
    /// as the dirty flag, so the two can never disagree — and
    /// it counts SETTINGS, not leaves.
    @Test("the draft count follows edits and reverts")
    func draftCountFollowsEdits() {
        let (model, _) = model()
        #expect(model.draftChangeCount == 0)
        model.config.settings.gapsGlobal.outer.top += 4
        #expect(model.isDirty)
        #expect(model.draftChangeCount == 1)
        model.config.settings.minWindowSize += 40
        #expect(model.draftChangeCount == 2)
        // Hand-undoing the edits clears the count with the
        // flag — a live comparison, never a latch.
        model.config = model.cleanConfig
        #expect(!model.isDirty)
        #expect(model.draftChangeCount == 0)
    }

    /// The reload path (revert, every save) must recompute the
    /// count, not just hand-set the flag — a bare
    /// `isDirty = false` left the chip showing a stale count on
    /// a clean draft (review 2026-08-04).
    @Test("revert clears the count through the reload path")
    func revertClearsTheCount() {
        let (model, _) = model()
        model.config.settings.gapsGlobal.outer.top += 4
        #expect(model.draftChangeCount == 1)
        model.revert()
        #expect(!model.isDirty)
        #expect(model.draftChangeCount == 0)
    }
}
