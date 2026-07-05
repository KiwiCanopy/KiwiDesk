import Foundation

/// The GUI dashboard's read/write bridge to the running core.
///
/// Reading: the dashboard opens the `gui.json` sidecar when it
/// exists, else seeds an editable model from live state. Any
/// hand-written Lua outside the managed block flips the editor
/// into raw-Lua fallback (`configHasForeignCode`).
///
/// Writing: the model is persisted to the sidecar and its
/// managed block spliced into `init.lua`, then the config is
/// reloaded so the change takes effect immediately.
extension KiwiCore {
    public var guiConfigStore: GuiConfigStore {
        GuiConfigStore(directory: configDirectory)
    }

    /// The editable model for the dashboard: the saved sidecar
    /// if present, otherwise a snapshot of live state.
    public func loadGuiConfig() -> GuiConfig {
        guiConfigStore.load() ?? guiConfigSeed()
    }

    /// Whether `init.lua` holds code outside the managed block
    /// (so the visual editor can't safely own the file).
    public var configHasForeignCode: Bool {
        guard
            let source = try? String(
                contentsOf: configURL,
                encoding: .utf8
            )
        else { return false }
        return ManagedConfig.hasForeignCode(source)
    }

    /// Persists the model and applies it: writes `gui.json`,
    /// regenerates `init.lua`'s managed block, then reloads.
    public func saveGuiConfig(_ config: GuiConfig) throws {
        try guiConfigStore.save(config)
        try writeManagedBlock(for: config)
        loadConfig()
    }

    /// Splices a freshly generated managed block into the
    /// existing `init.lua`, preserving surrounding user code.
    private func writeManagedBlock(
        for config: GuiConfig
    ) throws {
        let existing =
            (try? String(
                contentsOf: configURL,
                encoding: .utf8
            )) ?? ""
        let block = LuaConfigWriter.block(for: config)
        let merged = ManagedConfig.merge(
            block: block,
            into: existing
        )
        try FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true
        )
        try merged.write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    /// Migrates a hand-written config into GUI management: the
    /// current file is preserved verbatim as a commented backup,
    /// and a fresh managed block is generated from the live
    /// (executed) state — gaps, layouts, and rules carry over.
    /// Keybindings can't be recovered from executed Lua, so they
    /// remain only in the backup for the user to re-enter.
    /// Returns the seeded model now under GUI ownership.
    @discardableResult
    public func adoptConfigIntoGui() throws -> GuiConfig {
        let original =
            (try? String(
                contentsOf: configURL,
                encoding: .utf8
            )) ?? ""
        let config = guiConfigSeed()
        try guiConfigStore.save(config)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let file = ManagedConfig.adopt(
            original: original,
            block: LuaConfigWriter.block(for: config),
            date: formatter.string(from: .now)
        )
        try FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true
        )
        try file.write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )
        loadConfig()
        return config
    }

    /// Builds an editable model from the running configuration.
    /// Keybinding actions and mode icons can't be recovered
    /// from live Lua state, so modes start with just an empty
    /// default (the sidecar owns them once saved).
    func guiConfigSeed() -> GuiConfig {
        var config = GuiConfig()
        config.settings = tiler.settings
        config.appRules = state.appRules
        config.floatRules = eventLoop.floatRules.rawRules
        var modes: [SpaceID: LayoutMode] = [:]
        var defined: [SpaceID] = []
        for space in state.workspaces.allSpaces {
            defined.append(space.id)
            if space.mode != .bsp { modes[space.id] = space.mode }
        }
        config.spaceModes = modes
        config.spaces = GuiConfig.orderedSpaces(
            defined + Array(modes.keys)
        )
        if config.spaces.isEmpty {
            config.spaces = (1...5).map { SpaceID($0) }
        }
        var bindings: [Int: String] = [:]
        for (number, name) in nativeSpaceBindings {
            bindings[number] = name
        }
        config.profileBindings = bindings
        return config
    }
}
