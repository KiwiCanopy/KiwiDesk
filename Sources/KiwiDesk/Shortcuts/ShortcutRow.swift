import Foundation
import KiwiDeskCore

/// One row in the read-only shortcuts reference: a label, the
/// rendered key-combo glyph string, and an optional leading glyph
/// (a space icon) or app bundle id (a real app icon). Pure value
/// data — the view owns all presentation.
struct ShortcutRow: Identifiable {
    let id: String
    let label: String
    /// The combo rendered as native glyphs (`⌃⌥←`), through the
    /// same `ComboSymbols` path the editor uses.
    let combo: String
    /// Leading SF Symbol / emoji glyph (space rows). Nil = none.
    var icon: String? = nil
    /// App bundle id for a real 20pt icon (Apps band). Nil = none.
    var bundleID: String? = nil
    /// App Font ligature (#294): set when the bar's icon source
    /// is Glyphs and this app has one, so the panel's Apps band
    /// matches the bar. Wins over `bundleID`; nil falls back to
    /// the bundle icon.
    var glyph: String? = nil
    /// Custom-Lua rows render their label monospaced.
    var monospaced: Bool = false
    /// Trailing accessory glyph for a non-default launch behavior
    /// (#334: Open New). Nil = default row, which renders exactly
    /// as before. `accessoryHelp` is its hover tooltip.
    var accessoryIcon: String? = nil
    var accessoryHelp: String = ""
}

/// A named group of rows inside the Controls band (Focus / Move
/// Windows / Size & float / Switch modes).
struct ShortcutSubgroup: Identifiable {
    let title: String
    let rows: [ShortcutRow]
    var id: String { title }
}

/// The whole read-only reference for one key mode: four bands
/// (Controls grouped by subgroup, Inactive, Apps, Custom). Empty
/// bands are dropped by the builder, so an empty band never
/// renders.
struct ShortcutsReference {
    // `var`, not `let`: post-processing (the #294 glyph pass)
    // mutates a copy instead of re-initializing memberwise,
    // which would be one more hand-mirrored field list.
    var layerName: String
    var controls: [ShortcutSubgroup]
    /// Bindings whose target Space has left the current list
    /// (#820) — surfaced under their real name, dimmed, never
    /// pruned and never left to the Custom band.
    var inactive: [ShortcutRow] = []
    var apps: [ShortcutRow]
    var custom: [ShortcutRow]

    /// True when the active mode has no *listable* bound
    /// shortcuts — the view shows a "nothing bound yet"
    /// placeholder. The panel's own opener doesn't count (see
    /// the builder): a fresh mode holding only the seeded ⌃⌥K
    /// row reads as empty here while the footer shows the combo
    /// (when live).
    var isEmpty: Bool {
        controls.isEmpty && inactive.isEmpty && apps.isEmpty
            && custom.isEmpty
    }
}
