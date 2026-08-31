import KiwiDeskCore

/// Localized display name resolution for stored keybinding labels (#96).
extension KeybindingCatalog {
    /// Resolves localized display name for persisted label
    /// (`KeybindingImportClassifier.navigationLabels`, #96).
    @MainActor static func localizedLabel(
        for label: String,
        config: GuiConfig
    ) -> String {
        guard !label.isEmpty else { return label }
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
        guard
            let match = commands.first(where: {
                $0.label == label
            })
        else { return label }
        return match.resolvedLabel
    }
}
