import KiwiDeskCore

/// The Shortcuts readout's naming half, split from
/// `SettingsValueReadout+Shortcuts.swift` for the file-size
/// target (AGENTS.md §2.1): a binding's row label resolved the
/// way the area's own rows resolve it — the `KeybindingCatalog`
/// command for its Lua, the app display name for an app row —
/// and its combo rendered through the recorder's own
/// `ComboSymbols` + `LayoutKeyGlyph` pipeline (#23), never a
/// second combo renderer.
extension SettingsValueReadout {
    /// Lua action → localized row label, built from the same
    /// catalog builders the editor and the ⌃⌥K panel render
    /// from. Space-targeting commands come from the union of
    /// both sides' space lists and resize commands from both
    /// sides' steps, so a row keeps its name even when the
    /// draft also renamed the thing it targets.
    static func shortcutsActionLabels(
        old: GuiConfig,
        new: GuiConfig
    ) -> [String: String] {
        var spaces: [SpaceID] = []
        for space in old.spaces + new.spaces
        where !spaces.contains(space) {
            spaces.append(space)
        }
        var layerNames: [String] = []
        for layer in old.layers + new.layers
        where !layerNames.contains(layer.name) {
            layerNames.append(layer.name)
        }
        var commands =
            KeybindingCatalog.focusDirections
            + KeybindingCatalog.goToSpace(spaces)
            + KeybindingCatalog.swapDirections
            + KeybindingCatalog.moveToTrackRows
            + KeybindingCatalog.trackSwapRows
            + KeybindingCatalog.moveToSpace(spaces)
            + [
                KeybindingCatalog.showShortcuts,
                KeybindingCatalog.openSettings,
            ]
            + layerNames.map(
                KeybindingCatalog.switchLayerCommand
            )
        let steps = Set([
            Int(old.settings.resizeStep),
            Int(new.settings.resizeStep),
        ])
        for step in steps.sorted() {
            commands += KeybindingCatalog.resizeAndFloat(
                step: step
            )
        }
        var labels: [String: String] = [:]
        for command in commands
        where labels[command.lua] == nil {
            labels[command.lua] = command.resolvedLabel
        }
        return labels
    }

    /// The binding's row label as the Shortcuts area shows it:
    /// catalog command label, else the app's display name, else
    /// the stored editor label, else the raw Lua — the same
    /// ladder the ⌃⌥K panel's bands fall through.
    static func shortcutsBindingLabel(
        _ binding: KeyBinding,
        labels: [String: String]
    ) -> String {
        if let label = labels[binding.lua] { return label }
        if binding.kind == .application,
            let bundleID = KeybindingCatalog.appBundleID(
                from: binding.lua
            )
        {
            return KeybindingCatalog.displayName(
                forBundleID: bundleID
            )
        }
        if !binding.label.isEmpty { return binding.label }
        return binding.lua
    }

    /// The recorder's own combo rendering (#23): native glyphs
    /// mapped through the active keyboard layout, the raw
    /// string on a parse failure, the unset dash while
    /// unrecorded.
    static func shortcutsCombo(_ combo: String) -> String {
        guard !combo.isEmpty else { return unset }
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
