import KiwiDeskCore

/// A preset navigation action: a label and the Lua body it
/// binds to. `label` is the stable, English canonical text —
/// it is what the import classifier matches on (keyed off
/// `lua`, never displayed text) and what persists into
/// `KeyBinding.label` (`KeyLayer.sameAction` already documents
/// `label` as display-only metadata for the override cascade).
/// `displayLabel` is the localized string shown in the GUI —
/// resolved separately so a language switch never rewrites the
/// persisted/matched `label`. See `KeybindingImportClassifier`.
struct NavCommand: Identifiable, Hashable {
    let label: String
    let lua: String
    /// Optional space icon (#68 §6.5) shown before the label
    /// — recognition sugar only; labels stay authoritative
    /// (the import classifier matches on label + Lua).
    var icon: String? = nil
    /// The localized text the GUI renders. Defaults to
    /// `{ label }` (no translation needed, e.g. a space name);
    /// catalog builders that carry a translatable key supply
    /// this explicitly.
    var displayLabel: @MainActor () -> String = { "" }
    /// Optional contextual-help text (#94) for a `?` affordance
    /// beside the row label — set only where a preset carries a
    /// real limitation a user would otherwise hit blind (#420
    /// tiled-sticky reorder limit). Excluded from `==`/`hash`
    /// like `displayLabel`: identity stays label + Lua + icon.
    var help: (@MainActor () -> String)? = nil
    /// Why this row's ACTION cannot run right now, or nil when
    /// it can — the Desktop rows' "that screen is unplugged".
    ///
    /// Not a disabled flag: the row stays fully editable,
    /// because recording a key for a Desktop that is away is
    /// exactly what a docked-and-undocked user is doing. It
    /// dims and says why (`keybindingRowStyle`), the way an
    /// inherited row does.
    ///
    /// Excluded from `==`/`hash` with `displayLabel` and `help`:
    /// identity stays label + Lua + icon, and a row is the same
    /// row whether or not its screen is plugged in — the import
    /// classifier and `NavRow`'s own keying depend on that.
    var unavailable: (@MainActor () -> String)? = nil
    var id: String { lua }

    @MainActor var resolvedLabel: String {
        let resolved = displayLabel()
        return resolved.isEmpty ? label : resolved
    }

    static func == (lhs: NavCommand, rhs: NavCommand) -> Bool {
        lhs.label == rhs.label && lhs.lua == rhs.lua
            && lhs.icon == rhs.icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(lua)
        hasher.combine(icon)
    }
}

/// A collapsible group of navigation commands (Focus — including
/// go-to-space — and Window Management: move, resize, float).
struct NavGroup: Identifiable {
    let title: String
    let commands: [NavCommand]
    var id: String { title }
}
