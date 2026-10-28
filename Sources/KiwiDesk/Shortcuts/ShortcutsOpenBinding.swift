import KiwiDeskCore

/// The live chord of a bound action (#330): the shortcuts panel's
/// own Lua body, so its catalog row, quick-menu display and footer
/// hint cannot drift apart, and the one reader every surface that
/// prints a live chord takes — the key panel's sides among them
/// (#2245).
enum ShortcutsOpenBinding {
    /// Lua statement for opening shortcuts panel.
    static let lua = KiwiHubSide.shortcuts.lua

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
        return ChordGlyphs.render(
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
        combo(core: core) { $0.lua == verb }
    }

    /// A lens's chord: the row that toggles it, however its name is
    /// spelled (#2103 ruling 39).
    @MainActor static func lensGlyphs(
        core: KiwiCore,
        lens name: String
    ) -> String? {
        guard let bindings = activeBindings(core: core) else {
            return nil
        }
        return lensCombo(in: bindings, lens: name).map {
            ChordGlyphs.render($0, layoutChar: LayoutKeyGlyph.char)
        }
    }

    /// The chord of the row in `bindings` that toggles `name`,
    /// however either spells it.
    static func lensCombo(
        in bindings: [KeyBinding],
        lens name: String
    ) -> KeyCombo? {
        bindings.first { KeybindingCatalog.isLensChord($0, name) }
            .flatMap { KeyCombo.parse($0.combo) }
    }

    @MainActor private static func combo(
        core: KiwiCore,
        matching row: (KeyBinding) -> Bool
    ) -> KeyCombo? {
        guard
            let combo = activeBindings(core: core)?.first(where: {
                row($0) && !$0.combo.isEmpty
            })?.combo,
            let parsed = KeyCombo.parse(combo)
        else { return nil }
        return parsed
    }

    /// The RESOLVED active layer's rows.
    @MainActor private static func activeBindings(
        core: KiwiCore
    ) -> [KeyBinding]? {
        guard let snapshot = core.liveKeybindingSnapshot() else {
            return nil
        }
        let layer =
            snapshot.keyLayers.first {
                $0.name == snapshot.activeLayerName
            } ?? snapshot.keyLayers.first
        return layer?.bindings
    }
}
