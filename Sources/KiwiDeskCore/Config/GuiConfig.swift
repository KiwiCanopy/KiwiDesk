import Foundation

/// The GUI's editable configuration split across global `gui.json` and
/// active profile JSON (#36, #55).
public struct GuiConfig: Codable, Equatable, Sendable {
    /// Format version of the gui.json schema (#902); 0 =
    /// unversioned legacy. **Deliberately NOT bumped by the
    /// scroll-duration rename (#1020)**: `settings` is absent from
    /// `CodingKeys`, so the renamed key never reaches this file —
    /// a bump would rewrite every gui.json for nothing and make
    /// the previous release refuse one this build wrote. That note
    /// is the ruling `SetupBundle.currentFormat` cites.
    ///
    /// **2 (#1147)**: `profile_bindings` values became objects,
    /// which IS a `CodingKeys` key of this file, so the step is
    /// dead without the bump.
    public static let currentFormat = 2

    public var format: Int = GuiConfig.currentFormat
    /// Active profile tiling parameters.
    public var settings = TilingSettings()
    /// User-defined Spaces in display order.
    public var spaces: [SpaceID] = []
    /// Layout mode per Space (profile-scoped). SPARSE: `.bsp`
    /// is the omitted default, so read it through `modes(for:)`
    /// rather than spelling that default again at a call site.
    public var spaceModes: [SpaceID: LayoutMode] = [:]

    /// This draft's mode for every space in `spaces`, dense.
    ///
    /// The sparse encoding omits `.bsp`, and a reader that
    /// spells that default itself is a second copy of it — which
    /// is how a mode-scoped write can disagree with the apply
    /// beside it (#1179).
    public func modes(
        for spaces: [SpaceID]
    ) -> [SpaceID: LayoutMode] {
        var dense: [SpaceID: LayoutMode] = [:]
        for space in spaces {
            dense[space] = spaceModes[space] ?? .bsp
        }
        return dense
    }

    /// App -> space assignment (`app_rules`).
    public var appRules: [String: SpaceID] = [:]
    /// Space -> monitor fingerprint pin (profile-scoped).
    public var spacePins: [SpaceID: String] = [:]
    /// Spaces following the main display (profile-scoped).
    public var mainSpaces: Set<SpaceID> = []
    /// Explicit fallback space when a profile switch drops spaces (#68).
    public var fallbackSpace: SpaceID?
    /// Windows that never tile (`float_rules`).
    public var floatRules: [String] = []
    /// Apps never managed (`ignore_rules`, #176).
    public var ignoreRules: [String] = []
    /// Desktop -> the profile it selects (#1147). Keyed by the
    /// Desktop's own stamp where it carries one, so a binding
    /// survives a renumber; by its Mission Control number where
    /// it does not (no bridge on this macOS, or a stamp declined).
    public var profileBindings: [DesktopKey: DesktopBinding] = [:]
    /// Keybinding modes; first is default mode.
    public var layers: [KeyLayer] = [KeyLayer.defaultLayer]

    public init() {}

    /// Renames a space across all references, overrides, and keybindings
    /// (#13).
    @discardableResult
    public mutating func renameSpace(
        from: SpaceID,
        to: SpaceID
    ) -> Bool {
        guard from != to else { return true }
        guard !to.raw.isEmpty else { return false }
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

    /// Deletes a space and all profile-scoped overrides (#68) — a
    /// pin left behind keeps the space in `Profile.declaredSpaces`
    /// and the next authoritative load resurrects it. Deliberately
    /// does NOT touch `appRules` (unlike `renameSpace`): app rules
    /// are global, and another profile may still declare a space
    /// of this name.
    public mutating func removeSpace(_ space: SpaceID) {
        spaces.removeAll { $0 == space }
        spaceModes[space] = nil
        spacePins[space] = nil
        mainSpaces.remove(space)
        if fallbackSpace == space { fallbackSpace = nil }
        settings.removeSpace(space)
    }

    /// True if deleting space would drop custom overrides (#205).
    /// The settings half probes by mutating a copy and comparing,
    /// so it can never drift from `TilingSettings.removeSpace`'s
    /// reflection-guarded map list.
    public func carriesOverrides(_ space: SpaceID) -> Bool {
        if spacePins[space] != nil { return true }
        if mainSpaces.contains(space) { return true }
        if fallbackSpace == space { return true }
        var probe = settings
        probe.removeSpace(space)
        return probe != settings
    }

    /// Only the global fields persist in the sidecar — the
    /// profile-scoped ones round-trip through the profile JSON
    /// instead (#36), which is what lets the two files never
    /// drift.
    private enum CodingKeys: String, CodingKey {
        case format
        case spaces
        case appRules = "app_rules"
        case floatRules = "float_rules"
        case ignoreRules = "ignore_rules"
        case profileBindings = "profile_bindings"
        case layers
    }

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
        // A hand-edited sidecar can carry duplicate mode names or
        // an icon on the default mode (#31) — normalized here so
        // invalid entries never reach the loader or the GUI.
        layers = KeyLayer.normalized(
            full: try container.decodeIfPresent(
                [KeyLayer].self,
                forKey: .layers
            ) ?? []
        )
        dropEmptyNamedSpaces()
    }

    private mutating func dropEmptyNamedSpaces() {
        // ONE definition of the reference sites (removeSpace)
        // rather than a third hand-mirror; only the appRules VALUE
        // filter stays separate.
        removeSpace(SpaceID(""))
        appRules = appRules.filter { !$0.value.raw.isEmpty }
    }

    /// Strict, per AGENTS.md §5: format 1's `"2": "Work"` is
    /// rewritten once by `ConfigMigration`, never read leniently
    /// here — a lenient reader never ends, so nothing would ever
    /// signal that the last file carrying the retired shape is
    /// gone.
    private func decodeProfileBindings(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [DesktopKey: DesktopBinding] {
        try container.decodeIfPresent(
            [DesktopKey: DesktopBinding].self,
            forKey: .profileBindings
        ) ?? [:]
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
        try container.encode(
            profileBindings,
            forKey: .profileBindings
        )
        try container.encode(layers, forKey: .layers)
    }
}
