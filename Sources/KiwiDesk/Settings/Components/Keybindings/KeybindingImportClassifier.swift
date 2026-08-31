import CoreGraphics
import KiwiDeskCore

/// Reclassifies `.custom` keybindings to `.navigation` or `.application`
/// via catalog matching (`KeybindingCatalog`, `recoverKeybindings`, #4).
enum KeybindingImportClassifier {
    /// Reclassifies custom rows in config in-place. Pass
    /// `recoverResizeStep` ONLY on an explicit import, where the
    /// pulled-in bindings are the source of truth — on a plain
    /// load-for-edit `resize.step` is already authoritative, and a
    /// magnitude baked into a stray row must not overwrite it
    /// (#58 review).
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
        // Desktop rows are absent on purpose, matched by SHAPE in
        // `reclassify`: this map is built from the config, which
        // records no Desktops — a live list would strand a binding
        // naming a detached Desktop as raw Lua until the screen
        // came back. Step-free rows each need an entry or an
        // imported binding stays Custom (#91).
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
