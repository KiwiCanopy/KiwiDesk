import KiwiDeskCore

/// Binding definitions and glyph rendering for opening shortcuts
/// panel (#330): one place owns the Lua body so the catalog row,
/// quick-menu display and footer hint cannot drift apart.
enum ShortcutsOpenBinding {
    /// Lua statement for opening shortcuts panel.
    static let lua = "KiwiDesk.show_shortcuts()"

    /// Formatted glyphs for the panel hotkey (`ComboSymbols`,
    /// #330), read from the RESOLVED active layer, never raw
    /// `gui.json` — the displayed combo must match what Carbon
    /// actually has installed.
    @MainActor static func comboGlyphs(core: KiwiCore) -> String? {
        guard let parsed = combo(core: core) else { return nil }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }

    /// Structured equivalent for AppKit menu rendering. Keeping the
    /// physical key code avoids lossy reverse-parsing of display
    /// glyphs such as F-keys and Home/Page Up.
    @MainActor static func combo(core: KiwiCore) -> KeyCombo? {
        guard let snapshot = core.liveKeybindingSnapshot() else {
            return nil
        }
        let layer =
            snapshot.keyLayers.first {
                $0.name == snapshot.activeLayerName
            } ?? snapshot.keyLayers.first
        guard
            let combo = layer?.bindings.first(where: {
                $0.lua == lua && !$0.combo.isEmpty
            })?.combo,
            let parsed = KeyCombo.parse(combo)
        else { return nil }
        return parsed
    }
}
