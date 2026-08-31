import CoreGraphics
import KiwiDeskCore

/// Reclassifies `.custom` keybindings to `.navigation` or `.application`
/// via catalog matching (`KeybindingCatalog`, `recoverKeybindings`, #4).
enum KeybindingImportClassifier {
    /// Reclassifies custom rows in config in-place (`resize.step`, #58).
    static func classify(
        _ config: inout GuiConfig,
        recoverResizeStep: Bool = false
    ) {
        let navigation = navigationLabels(for: config)
        var recoveredStep: Int?
        for layer in config.layers.indices {
            for row in config.layers[layer].bindings.indices {
                if let step = reclassify(
                    &config.layers[layer].bindings[row],
                    navigation: navigation
                ) {
                    recoveredStep = step
                }
            }
        }
        if recoverResizeStep, let recoveredStep {
            config.settings.resizeStep = CGFloat(recoveredStep)
        }
    }

    /// Maps Lua actions to labels (`stepFreeCommands`, #91, #221).
    private static func navigationLabels(
        for config: GuiConfig
    ) -> [String: String] {
        var map: [String: String] = [:]
        let groups = KeybindingCatalog.navigationGroups(
            spaces: config.spaces
        )
        for group in groups {
            for command in group.commands {
                map[command.lua] = command.label
            }
        }
        for name in config.layers.map(\.name) {
            let command = KeybindingCatalog.switchLayerCommand(name)
            map[command.lua] = command.label
        }
        for command in KeybindingCatalog.stepFreeCommands {
            map[command.lua] = command.label
        }
        return map
    }

    /// Reclassifies single binding row, returning recovered resize step (#58).
    @discardableResult
    private static func reclassify(
        _ binding: inout KeyBinding,
        navigation: [String: String]
    ) -> Int? {
        guard binding.kind == .custom else { return nil }
        if let shape = KeybindingCatalog.resizeShape(
            from: binding.lua
        ) {
            binding.kind = .navigation
            binding.label = shape.label
            return shape.step
        }
        if let command = KeybindingCatalog.desktopCommand(
            from: binding.lua
        ) {
            binding.kind = .navigation
            binding.label = command.label
        } else if let label = navigation[binding.lua] {
            binding.kind = .navigation
            binding.label = label
        } else if let bundleID = KeybindingCatalog.appBundleID(
            from: binding.lua
        ) {
            binding.kind = .application
            binding.label = KeybindingCatalog.displayName(
                forBundleID: bundleID
            )
        }
        return nil
    }
}
