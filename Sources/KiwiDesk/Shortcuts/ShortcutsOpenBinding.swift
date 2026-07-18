import KiwiDeskCore

/// The bindable "open the shortcuts panel" action (#330). One
/// place owns its Lua body so the catalog row, the quick-menu combo
/// display, and the panel's footer hint all speak of the same
/// binding — and a rename can't drift them apart.
enum ShortcutsOpenBinding {
    /// The Lua the catalog binds and the classifier recognizes.
    static let lua = "KiwiDesk.show_shortcuts()"

    /// The combo currently bound to open the panel, rendered as
    /// native glyphs (`⌥␣`) via the same `ComboSymbols` + layout
    /// path the editor and reference panel use — so it reads
    /// identically everywhere. Nil when nothing is bound, or when
    /// the live snapshot is unavailable (paused / init.lua-owned):
    /// there is no live combo to advertise then.
    ///
    /// Read from the RESOLVED active mode (post profile-override),
    /// not raw `gui.json` — the displayed combo must match what
    /// Carbon actually has installed.
    @MainActor static func comboGlyphs(core: KiwiCore) -> String? {
        guard let snapshot = core.liveKeybindingSnapshot() else {
            return nil
        }
        let mode =
            snapshot.keyModes.first {
                $0.name == snapshot.activeModeName
            } ?? snapshot.keyModes.first
        guard
            let combo = mode?.bindings.first(where: {
                $0.lua == lua && !$0.combo.isEmpty
            })?.combo,
            let parsed = KeyCombo.parse(combo)
        else { return nil }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
