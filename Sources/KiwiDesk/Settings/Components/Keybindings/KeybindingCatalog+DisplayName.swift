import CoreFoundation
import KiwiDeskCore

/// Localized display name resolution for stored keybinding labels (#96).
extension KeybindingCatalog {
    /// Resolves localized display name for persisted label
    /// (`KeybindingImportClassifier.navigationLabels`, #96).
    /// The Desktop half reads the BINDINGS, never a live list —
    /// the banner must still name a row whose screen is unplugged.
    /// A label outside the roster returns unchanged.
    @MainActor static func localizedLabel(
        for label: String,
        config: GuiConfig
    ) -> String {
        guard !label.isEmpty else { return label }
        guard
            let match = namedCommands(config).first(where: {
                $0.label == label
            })
        else { return label }
        return match.resolvedLabel
    }

    /// A binding's name wherever the GUI names one: its localized
    /// label, else the catalog command its Lua runs, else the Lua
    /// itself — the one door (#96, #2111,
    /// `BindingNameDoorTests`).
    @MainActor static func localizedName(
        of binding: KeyBinding,
        config: GuiConfig
    ) -> String {
        guard binding.label.isEmpty else {
            return localizedLabel(for: binding.label, config: config)
        }
        return namedCommands(config).first(where: {
            $0.lua == binding.lua
        })?.resolvedLabel ?? binding.lua
    }

    /// Every command a stored binding may be named after.
    @MainActor private static func namedCommands(
        _ config: GuiConfig
    ) -> [NavCommand] {
        var commands = navigationGroups(spaces: config.spaces)
            .flatMap(\.commands)
        commands += config.layers.map {
            switchLayerCommand($0.name)
        }
        commands += resizeAndFloat(
            step: Int(config.settings.resizeStep)
        )
        commands += stepFreeCommands
        let desktops = desktopOffer(
            live: [],
            bindings: config.layers.flatMap(\.bindings)
        )
        commands += goToDesktop(desktops.desktops)
        commands += moveToDesktop(desktops.desktops)
        return commands
    }
}
