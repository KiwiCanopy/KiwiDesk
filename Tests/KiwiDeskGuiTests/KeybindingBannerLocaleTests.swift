import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The conflict banner narrates binding names in the user's
/// locale (#96): `KeyBinding.label` is the stable ENGLISH
/// canonical, and the banner resolves it through the catalog
/// roster before interpolating — "Focus window to the left"
/// inside a German sentence is the shipped defect this guards
/// (owner, 2026-08-10). A BEHAVIOR test, not a needle, on the
/// prover's own advice: it reds on a dropped `localized(_:)`
/// consult AND on a roster entry going missing, which no
/// source scan can see. `.serialized` because
/// `LocalizationManager` is a process-wide singleton (the
/// `ImportClassifierLanguageTests` precedent).
///
/// Stated coupling (code review 2026-08-10): the assertions
/// lean on the shipped `de` catalog carrying
/// `keybinding.focus_dir` / `keybinding.dir.left` — a
/// legitimate `drop-key` on either reds this suite with the
/// wiring intact. Accepted: the expectation is built through
/// the SAME `L()` calls production uses, so the coupling is to
/// one corpus both sides read, and an injected-roster seam
/// would cost a production parameter for a test's comfort.
@Suite("Keybinding banner locale", .serialized)
@MainActor
struct KeybindingBannerLocaleTests {
    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    @Test("the banner names bindings in the active locale")
    func bannerNamesBindingsInGerman() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        let model = makeTestModel()
        model.config.spaces = [SpaceID("1")]
        model.config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "KiwiDesk.focus(\"left\")",
                        kind: .navigation,
                        label: "Focus window to the left"
                    ),
                    KeyBinding(
                        combo: "alt+h",
                        lua: "KiwiDesk.focus(\"right\")",
                        kind: .navigation,
                        label: "Focus window to the right"
                    ),
                ]
            )
        ]
        model.warnIfAnyConflict()
        let warning = model.keybindingWarning
        #expect(warning != nil)
        // The per-row tooltip narrates through the same roster
        // (its popover made the raw canonical clickable —
        // l10n review 2026-08-10).
        let bindings = model.config.layers[0].bindings
        let tooltip = ConflictText.tooltip(
            for: bindings[0],
            in: bindings,
            config: model.config
        )
        // Pinned non-nil first: `?.contains != true` alone
        // passes on a vanished tooltip (guard-prover's
        // fail-open note, 2026-08-10).
        #expect(tooltip != nil)
        #expect(
            tooltip?.contains("Focus window to the right")
                != true
        )
        // The de catalog's own rendering of the roster label —
        // read through the same L() the banner uses, so a
        // retuned translation moves both sides together.
        let localized = L(
            "keybinding.focus_dir",
            "Focus window %1$@",
            L("keybinding.dir.left", "to the left")
        )
        #expect(warning?.contains(localized) == true)
        // The English canonical must NOT surface — its
        // appearance is exactly the defect.
        #expect(
            warning?.contains("Focus window to the left")
                != true
        )
    }

    /// The banner must be able to reach zero (#1094).
    ///
    /// `noteRecordedCombo` clears only on `list.isEmpty`, so a
    /// conflict that can never leave the list latches the banner
    /// open: fixing every real clash refreshes it instead of
    /// dismissing it. `⌃⌥⌘8` is exactly that shape — a SEEDED
    /// row (tier 3's move-to-space-8) against a macOS chord that
    /// ships disabled — which is why aggregate surfaces read
    /// `KeybindingConflicts.actionable` and not `conflicts`.
    @Test("a dormant macOS chord cannot latch the banner open")
    func dormantChordDoesNotLatchTheBanner() {
        reset()
        defer { reset() }
        let model = makeTestModel()
        model.config.spaces = [SpaceID("1")]
        let seeded = KeyBinding(
            combo: "control+option+command+8",
            lua: "KiwiDesk.move_to_space_and_follow(\"8\")",
            kind: .navigation,
            label: "Move to Space 8 & follow"
        )
        let clash = KeyBinding(
            combo: "alt+h",
            lua: "KiwiDesk.focus(\"left\")",
            kind: .navigation,
            label: "Focus window to the left"
        )
        let twin = KeyBinding(
            combo: "alt+h",
            lua: "KiwiDesk.focus(\"right\")",
            kind: .navigation,
            label: "Focus window to the right"
        )
        model.config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [seeded, clash, twin]
            )
        ]
        model.warnIfAnyConflict()
        #expect(model.keybindingWarning != nil)
        // Resolve the only REAL conflict; the dormant one stays.
        var layer = model.config.layers[0]
        layer.bindings = [seeded, clash]
        model.config.layers = [layer]
        model.noteRecordedCombo(clash, in: layer.bindings)
        #expect(
            model.keybindingWarning == nil,
            "the banner latched open on a dormant chord"
        )
    }

}
