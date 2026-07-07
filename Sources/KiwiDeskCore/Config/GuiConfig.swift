import Foundation

/// The GUI's complete editable configuration.
///
/// The model splits along the profile boundary (#36):
///
/// - **Global fields** (spaces list, app rules, float rules,
///   profile bindings, keybindings) persist in the `gui.json`
///   sidecar and are applied directly by the structured
///   loader on reload (#55) — `init.lua` is never generated.
/// - **Profile-scoped fields** (tiling settings, space modes,
///   monitor pins, Main role) are held in memory for editing
///   and persist into the active profile's JSON — never into
///   the sidecar or `init.lua`, so the two files can't drift.
///
/// `init.lua` is the user's own hooks-only Lua; code touching
/// managed vocabulary flips the raw editor (`ManagedConfig`).
public struct GuiConfig: Codable, Equatable, Sendable {
    /// Tunable tiling parameters (gaps, per-layout params,
    /// drag visuals). Mirrors the running `tiler.settings`;
    /// profile-scoped.
    public var settings = TilingSettings()
    /// The virtual spaces the user has defined, in display
    /// order. Drives the space lists across the GUI (layouts,
    /// navigation shortcuts, app assignment). A space can be
    /// listed with the default `bsp` mode and no other config.
    public var spaces: [SpaceID] = []
    /// Layout mode per virtual space (`set_mode`);
    /// profile-scoped.
    public var spaceModes: [SpaceID: LayoutMode] = [:]
    /// App -> space assignment (`app_rules`).
    public var appRules: [String: SpaceID] = [:]
    /// Space -> monitor fingerprint pin for the *live*
    /// arrangement; profile-scoped (stored per monitor set).
    public var spacePins: [SpaceID: String] = [:]
    /// Spaces assigned the Main role (they follow the current
    /// main display); profile-scoped, stored once per profile.
    public var mainSpaces: Set<SpaceID> = []
    /// Windows that never tile (`float_rules`).
    public var floatRules: [String] = []
    /// Profile bound per native macOS Space (Mission Control
    /// number -> profile name).
    public var profileBindings: [Int: String] = [:]
    /// Keybinding modes; the first is always the default mode.
    public var modes: [KeyMode] = [KeyMode.defaultMode]

    public init() {}

    /// Renames a space everywhere it is referenced (#13): the
    /// `spaces` list, `spaceModes`, `appRules`, the monitor pin
    /// and Main-role maps, the per-space
    /// `settings.gapsOverride` / `settings.placementOverride`
    /// maps, and the space-targeting Lua inside every
    /// keybinding. A no-op returning `false` when `from` is
    /// unknown or `to` already exists (the caller keeps the old
    /// name); renaming to the same id succeeds trivially.
    @discardableResult
    public mutating func renameSpace(
        from: SpaceID,
        to: SpaceID
    ) -> Bool {
        guard from != to else { return true }
        // An empty name is never a valid space (it would emit a
        // `[""]` key); reject it as a rename target.
        guard !to.raw.isEmpty else { return false }
        // `spaces` is the authoritative membership set; the caller's
        // collision check mirrors this guard. A `to` that lingers as
        // a key in another surface (hand-edited sidecar) is rare and
        // gets overwritten below — acceptable given `spaces` gates
        // what the GUI ever offers.
        guard spaces.contains(from), !spaces.contains(to) else {
            return false
        }
        spaces = spaces.map { $0 == from ? to : $0 }
        if let mode = spaceModes.removeValue(forKey: from) {
            spaceModes[to] = mode
        }
        if let pin = spacePins.removeValue(forKey: from) {
            spacePins[to] = pin
        }
        if mainSpaces.remove(from) != nil {
            mainSpaces.insert(to)
        }
        if let gaps = settings.gapsOverride.removeValue(
            forKey: from
        ) {
            settings.gapsOverride[to] = gaps
        }
        if let placement = settings.placementOverride
            .removeValue(forKey: from)
        {
            settings.placementOverride[to] = placement
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

    /// Moves `space` to the front of the ordered list. A no-op
    /// when `space` is absent or is already the first element.
    /// This is the primitive a future fallback-space chooser
    /// (#68) will call. Both save paths capture the same order
    /// since `applyProfileScopedState` reconciles the live
    /// order via `WorkspaceManager.reorder` (#75/#55), so the
    /// reorder reaches `Profile.spaces` from either one.
    public mutating func moveToFirst(_ space: SpaceID) {
        guard let index = spaces.firstIndex(of: space),
            index != 0
        else { return }
        spaces.remove(at: index)
        spaces.insert(space, at: 0)
    }

    /// Only the global fields persist in the sidecar — the
    /// profile-scoped ones (settings, modes, pins) round-trip
    /// through the profile JSON instead (#36).
    private enum CodingKeys: String, CodingKey {
        case spaces
        case appRules = "app_rules"
        case floatRules = "float_rules"
        case profileBindings = "profile_bindings"
        case modes
    }

    /// Lenient decoding: a field missing from an older sidecar
    /// falls back to its default (same policy as profiles).
    /// Legacy tiling keys in an old sidecar are simply ignored.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        spaces =
            try container.decodeIfPresent(
                [SpaceID].self,
                forKey: .spaces
            ) ?? []
        appRules =
            try container.decodeIfPresent(
                [String: SpaceID].self,
                forKey: .appRules
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
        dropEmptyNamedSpaces()
    }

    /// Empty space names are blocked at every GUI entry point
    /// (`SpacesTab` add/rename); this drops any that slipped in
    /// through a hand-edited sidecar so a `[""]` key never reaches
    /// the writer. Glyph/symbol names are unaffected.
    private mutating func dropEmptyNamedSpaces() {
        spaces.removeAll { $0.raw.isEmpty }
        spaceModes = spaceModes.filter { !$0.key.raw.isEmpty }
        spacePins = spacePins.filter { !$0.key.raw.isEmpty }
        mainSpaces = mainSpaces.filter { !$0.raw.isEmpty }
        appRules = appRules.filter { !$0.value.raw.isEmpty }
        settings.gapsOverride = settings.gapsOverride.filter {
            !$0.key.raw.isEmpty
        }
        settings.placementOverride =
            settings.placementOverride.filter {
                !$0.key.raw.isEmpty
            }
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
        try container.encode(spaces, forKey: .spaces)
        try container.encode(appRules, forKey: .appRules)
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
