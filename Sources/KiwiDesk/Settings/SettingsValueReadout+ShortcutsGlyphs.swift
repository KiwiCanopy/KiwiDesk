import KiwiDeskCore

/// Shortcut action label resolution and glyph rendering for settings readout
/// (#23).
extension SettingsValueReadout {
    /// Builds localized action labels from the union of BOTH
    /// sides' space lists and resize steps, so a row keeps its
    /// name even when the draft also renamed the thing it targets.
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
            + desktopCommands(old: old, new: new)
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

    /// Desktop rows read from the BINDINGS, never a live Desktop
    /// list: a config records no Desktops, and the diff must name
    /// a row whatever is plugged in while it is read.
    private static func desktopCommands(
        old: GuiConfig,
        new: GuiConfig
    ) -> [NavCommand] {
        let bindings = (old.layers + new.layers).flatMap(
            \.bindings
        )
        let desktops = KeybindingCatalog.desktopOffer(
            live: [],
            bindings: bindings
        )
        return KeybindingCatalog.goToDesktop(desktops.desktops)
            + KeybindingCatalog.moveToDesktop(desktops.desktops)
    }

    /// Resolves display label for keybinding.
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

    /// Formats shortcut combo string into native glyphs (#23).
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
