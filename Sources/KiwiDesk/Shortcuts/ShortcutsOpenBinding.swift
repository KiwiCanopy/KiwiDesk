import KiwiDeskCore

/// The live chord of a bound action (#330): the shortcuts panel's
/// own Lua body, so its catalog row, quick-menu display and footer
/// hint cannot drift apart, and the one reader every surface that
/// prints a live chord takes — the key panel's sides among them
/// (#2245).
enum ShortcutsOpenBinding {
    /// Lua statement for opening shortcuts panel.
    static let lua = "KiwiDesk.show_shortcuts()"

    /// Formatted glyphs for the panel hotkey (`ComboSymbols`,
    /// #330), read from the RESOLVED active layer, never raw
    /// `gui.json` — the displayed combo must match what Carbon
    /// actually has installed.
    @MainActor static func comboGlyphs(
        core: KiwiCore,
        lua verb: String
    ) -> String? {
        guard let parsed = combo(core: core, lua: verb) else {
            return nil
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }

    /// Structured equivalent for AppKit menu rendering. Keeping the
    /// physical key code avoids lossy reverse-parsing of display
    /// glyphs such as F-keys and Home/Page Up.
    @MainActor static func combo(
        core: KiwiCore,
        lua verb: String
    ) -> KeyCombo? {
        guard let snapshot = core.liveKeybindingSnapshot() else {
            return nil
        }
        let layer =
            snapshot.keyLayers.first {
                $0.name == snapshot.activeLayerName
            } ?? snapshot.keyLayers.first
        guard
            let combo = layer?.bindings.first(where: {
                $0.lua == verb && !$0.combo.isEmpty
            })?.combo,
            let parsed = KeyCombo.parse(combo)
        else { return nil }
        return parsed
    }
}
