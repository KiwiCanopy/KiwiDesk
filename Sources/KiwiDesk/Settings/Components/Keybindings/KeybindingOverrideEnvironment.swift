import KiwiDeskCore
import SwiftUI

/// Environment plumbing for the Shortcuts tab's override layer
/// (#55 phase 7): while editing a stored profile the tab shows
/// the RESOLVED layers (base + the profile's sparse override).
/// Rows equal to their base gui.json row are inherited and
/// render dimmed; rows that diverge are this profile's
/// overrides and render at full strength — the same
/// inherited/overridden affordance as the per-space layout
/// overrides (#17). nil = live editing, no affordance.
private struct KeybindingOverrideBaseKey: EnvironmentKey {
    static let defaultValue: [KeyBinding]? = nil
}

private struct KeybindingLayerNameKey: EnvironmentKey {
    static let defaultValue = KeyLayer.defaultName
}

extension EnvironmentValues {
    /// The selected layer's base bindings while the Shortcuts
    /// tab edits a stored profile; nil during live editing.
    var keybindingOverrideBase: [KeyBinding]? {
        get { self[KeybindingOverrideBaseKey.self] }
        set { self[KeybindingOverrideBaseKey.self] = newValue }
    }

    /// Layer whose recorder rows are currently rendered. The
    /// live-apply seam uses it without threading another value
    /// through every intent-section wrapper.
    var keybindingLayerName: String {
        get { self[KeybindingLayerNameKey.self] }
        set { self[KeybindingLayerNameKey.self] = newValue }
    }
}

extension KeyBinding {
    /// Whether this row is inherited unchanged from `base` —
    /// SEMANTIC match (`sameAction`: combo + lua), so the GUI
    /// import classifier's display-only kind/label upgrades
    /// never render an untouched row as overridden. Always
    /// false outside override layer (`base == nil`).
    func isInherited(from base: [KeyBinding]?) -> Bool {
        base?.contains { $0.sameAction(as: self) } == true
    }
}

extension View {
    /// Dimmed when inherited, full strength when overridden
    /// or while editing live.
    ///
    /// The dim carries the whole distinction, so it also goes out
    /// as a spoken hint (#678 Phase 4 pass 10, turn 20a rule 3).
    /// The only explanation on screen is a caption at the top of
    /// the card — "Dimmed rows are inherited from the base" —
    /// which a screen-reader user reaches once, long before the
    /// row it explains, and cannot re-read from inside the list.
    /// A per-row hint is the version that survives arriving at
    /// row forty by keyboard.
    ///
    /// One site, three consumers (the nav rows, the app group and
    /// the raw-Lua drawer), which is why the hint belongs on the
    /// shared modifier rather than at each of them.
    ///
    /// **Unverified in one respect, and kept anyway because the
    /// two outcomes are not symmetric**: this modifier is applied
    /// to a whole ROW, and whether a hint on a container reaches
    /// the control inside it could not be observed headlessly
    /// (see `GreyOut`, where the same question sent the same
    /// change back out). Here the worse case is that the hint is
    /// inert — nothing in a keybinding row sets a hint of its
    /// own, so there is none for an empty inherited value to
    /// displace. `GreyOut` was backed out because there the worse
    /// case was DELETING hints that ship today. Confirm both in
    /// one Accessibility Inspector pass.
    /// **This hint names no control, deliberately, against #830's
    /// table.** That issue listed it as quoting `key_recorder
    /// .record` ("Record") and the conversion interpolated it —
    /// which was wrong twice. Grammatically, the label sat in the
    /// sentence's VERB slot, which only works in English: `es`,
    /// `it`, `pt-BR` and `ru` repaired it by supplying a verb of
    /// their own, and `de` and `fr` shipped verbless clauses
    /// (localization audit, 2026-08-17). Referentially — the
    /// sharper half — `KeyRecorderField.label` renders "Record"
    /// only while `combo.isEmpty`, and an INHERITED row shows the
    /// combo it inherited. So the sentence named a word that is
    /// not on screen for the one row it describes, and a
    /// VoiceOver user, who has no visual context at all, would
    /// have been sent to look for it.
    ///
    /// Interpolation is the right answer when prose names a
    /// control the reader can see (#818). When the control's
    /// label is not on screen, the fix is not a better
    /// interpolation — it is to stop naming it.
    func keybindingRowStyle(inherited: Bool) -> some View {
        opacity(inherited ? 0.55 : 1)
            .accessibilityHint(
                inherited
                    ? L(
                        "shortcuts.row.inherited.axhint",
                        "Inherited from the base shortcuts. "
                            + "Set a key here to override it."
                    )
                    : ""
            )
    }
}
