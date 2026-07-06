import Foundation

/// The GUI's complete editable configuration.
///
/// This is the single source of truth the SwiftUI dashboard
/// edits and persists (to `gui.json`). `init.lua`'s managed
/// block is regenerated from it (see `LuaConfigWriter`), so the
/// visual editor never round-trips through parsed Lua. Anything
/// the user hand-writes outside the managed block is preserved
/// (see `ManagedConfig`).
public struct GuiConfig: Codable, Equatable, Sendable {
    /// Tunable tiling parameters (gaps, per-layout params,
    /// drag visuals). Mirrors the running `tiler.settings`.
    public var settings = TilingSettings()
    /// The virtual spaces the user has defined, in display
    /// order. Drives the space lists across the GUI (layouts,
    /// navigation shortcuts, app assignment). A space can be
    /// listed with the default `bsp` mode and no other config.
    public var spaces: [SpaceID] = []
    /// Layout mode per virtual space (`set_mode`).
    public var spaceModes: [SpaceID: LayoutMode] = [:]
    /// App -> space assignment (`app_rules`).
    public var appRules: [String: SpaceID] = [:]
    /// Space -> monitor fingerprint priority chain
    /// (`space_monitor_map`). The GUI authors a single-element
    /// chain per space; hand-written configs may list several.
    public var spaceMonitorMap: [SpaceID: [String]] = [:]
    /// Windows that never tile (`float_rules`).
    public var floatRules: [String] = []
    /// Profile bound per native macOS Space (Mission Control
    /// number -> profile name).
    public var profileBindings: [Int: String] = [:]
    /// Keybinding modes; the first is always the default mode.
    public var modes: [KeyMode] = [KeyMode.defaultMode]

    public init() {}

    /// Renames a space everywhere it is referenced (#13): the
    /// `spaces` list, `spaceModes`, `appRules`, `spaceMonitorMap`,
    /// and the space-targeting Lua inside every keybinding. A
    /// no-op returning `false` when `from` is unknown or `to`
    /// already exists (the caller keeps the old name); renaming to
    /// the same id succeeds trivially.
    @discardableResult
    public mutating func renameSpace(
        from: SpaceID,
        to: SpaceID
    ) -> Bool {
        guard from != to else { return true }
        guard spaces.contains(from), !spaces.contains(to) else {
            return false
        }
        spaces = spaces.map { $0 == from ? to : $0 }
        if let mode = spaceModes.removeValue(forKey: from) {
            spaceModes[to] = mode
        }
        if let chain = spaceMonitorMap.removeValue(forKey: from) {
            spaceMonitorMap[to] = chain
        }
        for (app, space) in appRules where space == from {
            appRules[app] = to
        }
        modes = modes.map { mode in
            var mode = mode
            mode.bindings = mode.bindings.map { binding in
                var binding = binding
                binding.lua = SpaceLuaArg.rename(
                    in: binding.lua,
                    from: from.raw,
                    to: to.raw
                )
                return binding
            }
            return mode
        }
        return true
    }

    /// De-duplicates and orders space ids for display: numeric
    /// ids ascending, then named ids alphabetically.
    public static func orderedSpaces(
        _ ids: [SpaceID]
    ) -> [SpaceID] {
        var seen: Set<String> = []
        var unique: [SpaceID] = []
        for id in ids where seen.insert(id.raw).inserted {
            unique.append(id)
        }
        return unique.sorted { first, second in
            switch (Int(first.raw), Int(second.raw)) {
            case (let left?, let right?): return left < right
            case (_?, nil): return true
            case (nil, _?): return false
            default: return first.raw < second.raw
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case settings
        case spaces
        case spaceModes = "space_modes"
        case appRules = "app_rules"
        case spaceMonitorMap = "space_monitor_map"
        case floatRules = "float_rules"
        case profileBindings = "profile_bindings"
        case modes
    }

    /// Lenient decoding: a field missing from an older sidecar
    /// falls back to its default (same policy as profiles).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = GuiConfig()
        settings =
            try container.decodeIfPresent(
                TilingSettings.self,
                forKey: .settings
            ) ?? defaults.settings
        spaces =
            try container.decodeIfPresent(
                [SpaceID].self,
                forKey: .spaces
            ) ?? []
        spaceModes =
            try container.decodeIfPresent(
                [SpaceID: LayoutMode].self,
                forKey: .spaceModes
            ) ?? [:]
        appRules =
            try container.decodeIfPresent(
                [String: SpaceID].self,
                forKey: .appRules
            ) ?? [:]
        spaceMonitorMap =
            try container.decodeIfPresent(
                [SpaceID: [String]].self,
                forKey: .spaceMonitorMap
            ) ?? [:]
        floatRules =
            try container.decodeIfPresent(
                [String].self,
                forKey: .floatRules
            ) ?? []
        profileBindings =
            try decodeProfileBindings(from: container)
        modes =
            try container.decodeIfPresent(
                [KeyMode].self,
                forKey: .modes
            ) ?? [KeyMode.defaultMode]
        if modes.isEmpty { modes = [KeyMode.defaultMode] }
    }

    /// JSON object keys are strings; native-space numbers are
    /// stored as `{"2": "Studio"}`.
    private func decodeProfileBindings(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [Int: String] {
        let raw =
            try container.decodeIfPresent(
                [String: String].self,
                forKey: .profileBindings
            ) ?? [:]
        var mapped: [Int: String] = [:]
        for (key, value) in raw {
            if let number = Int(key) { mapped[number] = value }
        }
        return mapped
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )
        try container.encode(settings, forKey: .settings)
        try container.encode(spaces, forKey: .spaces)
        try container.encode(spaceModes, forKey: .spaceModes)
        try container.encode(appRules, forKey: .appRules)
        try container.encode(
            spaceMonitorMap,
            forKey: .spaceMonitorMap
        )
        try container.encode(floatRules, forKey: .floatRules)
        var bindings: [String: String] = [:]
        for (number, name) in profileBindings {
            bindings[String(number)] = name
        }
        try container.encode(
            bindings,
            forKey: .profileBindings
        )
        try container.encode(modes, forKey: .modes)
    }
}
