import Foundation

/// The GUI's complete editable configuration.
/// Split along the profile boundary (#36):
/// - **Global fields** (spaces, app/float/ignore rules, profile
///   bindings, keybindings) persist in `gui.json` and apply
///   directly on reload (#55) — `init.lua` is never generated.
/// - **Profile-scoped fields** (tiling settings, space modes,
///   monitor pins, Main role) are held in memory for editing
///   and persist into the active profile's JSON — never into
///   the sidecar or `init.lua`, so the two files can't drift.
///
/// `init.lua` is the user's own hooks-only Lua; code touching
/// managed vocabulary flips the raw editor (`ManagedConfig`).
public struct GuiConfig: Codable, Equatable, Sendable {
    /// Format version of the gui.json schema (#902).
    /// Format 0 = unversioned legacy.
    public static let currentFormat = 1

    public var format: Int = GuiConfig.currentFormat
    /// Tunable tiling parameters (gaps, per-layout params,
    /// drag visuals). Mirrors the running `tiler.settings`;
    /// profile-scoped.
    public var settings = TilingSettings()
    /// The Spaces the user has defined, in display
    /// order. Drives the space lists across the GUI (layouts,
    /// navigation shortcuts, app assignment). A space can be
    /// listed with the default `bsp` mode and no other config.
    public var spaces: [SpaceID] = []
    /// Layout mode per Space (`set_mode`);
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
    /// The explicitly designated rehome target (#68): where
    /// windows land when a profile switch drops their space.
    /// Profile-scoped (rides the profile JSON, like the pins);
    /// nil falls back to the order's first surviving space.
    public var fallbackSpace: SpaceID?
    /// Windows that never tile (`float_rules`).
    public var floatRules: [String] = []
    /// Apps never managed (`ignore_rules`); no GUI control (#176).
    public var ignoreRules: [String] = []
    /// Profile bound per native macOS Space (Mission Control
    /// number -> profile name).
    public var profileBindings: [Int: String] = [:]
    /// Keybinding modes; the first is always the default mode.
    public var layers: [KeyLayer] = [KeyLayer.defaultLayer]

    public init() {}

    /// Renames a space everywhere it is referenced (#13): the
    /// `spaces` list, `spaceModes`, `appRules`, the monitor pin
    /// and Main-role maps, the fallback-space reference, every
    /// per-space settings map (`TilingSettings.renameSpace` —
    /// gaps, placement, icons, layout overrides), and the
    /// space-targeting Lua inside every
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
        if fallbackSpace == from { fallbackSpace = to }
        settings.renameSpace(from: from, to: to)
        for (app, space) in appRules where space == from {
            appRules[app] = to
        }
        layers = layers.map { layer in
            var layer = layer
            layer.bindings = layer.bindings.map { binding in
                var binding = binding
                binding.lua = SpaceLuaArg.rename(
                    in: binding.lua,
                    from: from.raw,
                    to: to.raw
                )
                return binding
            }
            return layer
        }
        return true
    }

    /// Deletes a space and every profile-scoped reference it
    /// holds (#68): the list entry, its mode, monitor pin,
    /// Main role, fallback designation, and all per-space
    /// settings maps (`TilingSettings.removeSpace`). Without
    /// this, a pin or override left behind keeps the space in
    /// `Profile.declaredSpaces` and the next authoritative
    /// profile load resurrects it. Deliberately does NOT touch
    /// `appRules` (unlike `renameSpace`): app rules are
    /// global, and another profile may still declare a space
    /// of this name — a per-profile delete must not drop them.
    public mutating func removeSpace(_ space: SpaceID) {
        spaces.removeAll { $0 == space }
        spaceModes[space] = nil
        spacePins[space] = nil
        mainSpaces.remove(space)
        if fallbackSpace == space { fallbackSpace = nil }
        settings.removeSpace(space)
    }

    /// Whether deleting `space` would silently drop non-trivial
    /// per-space work — the destructive-delete confirm gate
    /// (#205). Counts a monitor pin, the Main role, the fallback
    /// designation, and any per-space settings override (gap,
    /// placement, icon, or a layout's own override map). The
    /// bare layout mode is core identity, not "override work",
    /// so it is not counted. The settings half probes by
    /// mutating a copy and comparing, so it can never drift from
    /// `TilingSettings.removeSpace`'s reflection-guarded map list.
    public func carriesOverrides(_ space: SpaceID) -> Bool {
        if spacePins[space] != nil { return true }
        if mainSpaces.contains(space) { return true }
        if fallbackSpace == space { return true }
        var probe = settings
        probe.removeSpace(space)
        return probe != settings
    }

    /// Only the global fields persist in the sidecar — the
    /// profile-scoped ones (settings, modes, pins) round-trip
    /// through the profile JSON instead (#36).
    private enum CodingKeys: String, CodingKey {
        case format
        case spaces
        case appRules = "app_rules"
        case floatRules = "float_rules"
        case ignoreRules = "ignore_rules"
        case profileBindings = "profile_bindings"
        case layers
    }

    /// Lenient decoding: a field missing from an older sidecar
    /// falls back to its default (same policy as profiles).
    /// Legacy tiling keys in an old sidecar are simply ignored.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let decodedFormat =
            try container.decodeIfPresent(
                Int.self,
                forKey: .format
            ) ?? 0
        guard decodedFormat <= Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription:
                    "gui config format \(decodedFormat) is newer "
                    + "than supported \(Self.currentFormat)"
            )
        }
        format = Self.currentFormat
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
        ignoreRules =
            try container.decodeIfPresent(
                [String].self,
                forKey: .ignoreRules
            ) ?? []
        profileBindings =
            try decodeProfileBindings(from: container)
        // Normalized like the spaces below: a hand-edited
        // sidecar can carry duplicate mode names or an icon on
        // the default mode (#31) — cleaned here so invalid
        // entries never reach the loader or the GUI. Empty
        // input falls back to [KeyLayer.defaultLayer] as before.
        layers = KeyLayer.normalized(
            full: try container.decodeIfPresent(
                [KeyLayer].self,
                forKey: .layers
            ) ?? []
        )
        dropEmptyNamedSpaces()
    }

    /// Empty space names are blocked at every GUI entry point
    /// (`SpacesTab` add/rename); this drops any that slipped in
    /// through a hand-edited sidecar so a `[""]` key never reaches
    /// the writer. Glyph/symbol names are unaffected.
    private mutating func dropEmptyNamedSpaces() {
        // ONE definition of the reference sites (removeSpace)
        // instead of a third hand-mirror of the list; only the
        // appRules *value* filter stays separate — decode-time
        // sanitization removeSpace rightly skips.
        removeSpace(SpaceID(""))
        appRules = appRules.filter { !$0.value.raw.isEmpty }
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
        try container.encode(format, forKey: .format)
        try container.encode(spaces, forKey: .spaces)
        try container.encode(appRules, forKey: .appRules)
        try container.encode(floatRules, forKey: .floatRules)
        try container.encode(ignoreRules, forKey: .ignoreRules)
        var bindings: [String: String] = [:]
        for (number, name) in profileBindings {
            bindings[String(number)] = name
        }
        try container.encode(
            bindings,
            forKey: .profileBindings
        )
        try container.encode(layers, forKey: .layers)
    }
}
