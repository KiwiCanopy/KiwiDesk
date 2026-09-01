import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts card's conflict shout against the live
/// symbolic-hotkeys verdict (#1094/#1105) — split from
/// `HomeCardContentTests` before the 350-line ceiling. Locale is
/// pinned in each body (#740); main-actor spend is one English
/// pin plus model construction, no scans.
@MainActor
@Suite("Home card conflict shout")
struct HomeCardConflictShoutTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    /// `⌃⌥⌘8` — tier 3's seeded move-to-space-8 row, and also
    /// Invert Colors.
    private func seededModel() -> SettingsModel {
        let model = makeTestModel()
        var layer = KeyLayer.defaultLayer
        layer.bindings = [
            KeyBinding(
                combo: "control+option+command+8",
                lua: "KiwiDesk.move_to_space_and_follow(\"8\")",
                kind: .navigation,
                label: "Move to Space 8 & follow"
            )
        ]
        model.config.layers = [layer]
        return model
    }

    /// A macOS chord the machine has DISABLED must not put a
    /// standing badge on the card: counting the dormant `⌃⌥⌘8`
    /// would shout on every install with 8+ Desktops about a
    /// chord that works for everyone who has not enabled it.
    ///
    /// The ROW keeps its warning: this asserts the shout is
    /// silent AND that `KeybindingConflicts` still reports the
    /// conflict, because suppressing both would take away the
    /// warning someone deliberately binding one of these needs
    /// — which is what the first draft of the #1094 fix did.
    @Test("a dormant macOS chord does not shout, but still warns")
    func dormantSystemChordIsNotShouted() {
        pinEnglish()
        let model = seededModel()
        let bindings = model.config.layers[0].bindings
        // The register knows it, so the row can explain itself…
        #expect(
            KeybindingConflicts.conflict(
                for: bindings[0],
                in: bindings
            ) != nil
        )
        // …and the card stays quiet about it —
        // `makeTestModel`'s reader answers nil, so the shipped
        // default (Invert Colors OFF) rules the verdict.
        #expect(
            HomeCardContent.conflictShout(
                for: .shortcuts,
                model: model
            ) == nil
        )
    }

    /// The other population, the one the static set was wrong
    /// for (#1105): a user who HAS enabled Invert Colors owns a
    /// live `⌃⌥⌘8`, so the seeded row is genuinely dead and the
    /// card says so.
    @Test("an enabled macOS chord shouts")
    func enabledSystemChordShouts() {
        pinEnglish()
        let model = seededModel()
        let invert = SystemShortcut.invertColors.symbolicHotkey!.id
        // The machine answers: Invert Colors is ON.
        model.readSymbolicHotkey = { id in
            id == invert ? true : nil
        }
        #expect(
            HomeCardContent.conflictShout(
                for: .shortcuts,
                model: model
            ) == L("home.card.conflict_one", "1 conflict")
        )
    }
}
