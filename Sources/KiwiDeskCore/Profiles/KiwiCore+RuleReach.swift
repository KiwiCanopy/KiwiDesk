import Foundation

/// The App Rules families across the shared base and every
/// readable profile (#1393), as the Settings checklist edits them.
public struct RuleReachSnapshot: Equatable, Sendable {
    public var appRules: RuleReachTable<SpaceID>
    public var floatRules: RuleReachTable<[String]>
    /// Shortcuts, one action per layer (#1393's second half).
    public var keyLayers: RuleReachTable<String>
    /// The scroll gestures, one field per key (#1656).
    public var scrollGestures: RuleReachTable<ScrollGestureValue>
    public let storedScrollBase: ScrollGestureBase
    /// The Space history setting, one key (#1655).
    public var spaceHistory: RuleReachTable<SpaceHistoryKind>
    /// The layout cycle, one key (#453).
    public var modeCycle: RuleReachTable<[LayoutMode]>
    /// The Tile list and the Automatic floating switch
    /// (#2173).
    public var tileRules: RuleReachTable<[String]>
    public var floatAutomatically: RuleReachTable<Bool>
    public let storedTileBase: [String]
    public let storedTileOverrides: [String: RuleListOverride]
    /// The shortcut base and overrides the key table reads: the
    /// files, with the draft's layer edits laid over them
    /// (`rewriteLayers`, #2022).
    public internal(set) var storedKeyBase: [KeyLayer]
    public internal(set) var storedKeyOverrides: [String: KeyLayerOverride]
    /// The shortcut base and overrides as the files hold them —
    /// what a save compares against to know what it must write.
    public let fileKeyBase: [KeyLayer]
    public let fileKeyOverrides: [String: KeyLayerOverride]
    /// A row to write for each key, from the stored layers; the
    /// Settings draft adds its own before saving.
    public var keyTemplates: [String: KeyBinding]
    /// The stored bases and float overrides, re-encoded only
    /// where a change reached (`appRuleBase`, `floatRuleOverride`).
    public let storedAppBase: [String: SpaceID]
    public let storedFloatBase: [String]
    public let storedFloatOverrides: [String: RuleListOverride]
    /// Profiles whose file could not be read, listed so a shared
    /// rule never looks as if it covered them.
    public let unreadable: [String]
    /// Each profile's sparse `lens_reach` (#2103 ruling 38), with
    /// the draft's lens edits laid over it (`RuleReachSnapshot+Lenses`).
    public internal(set) var lensReach: [String: [String: Bool]]
    /// The marks as the files hold them, which a save compares
    /// against.
    public let fileLensReach: [String: [String: Bool]]

    public init(
        appRules: RuleReachTable<SpaceID>,
        floatRules: RuleReachTable<[String]>,
        keyLayers: RuleReachTable<String>,
        scrollGestures: RuleReachTable<ScrollGestureValue>,
        storedScrollBase: ScrollGestureBase,
        spaceHistory: RuleReachTable<SpaceHistoryKind>,
        modeCycle: RuleReachTable<[LayoutMode]>,
        tileRules: RuleReachTable<[String]>,
        floatAutomatically: RuleReachTable<Bool>,
        storedTileBase: [String],
        storedTileOverrides: [String: RuleListOverride],
        storedKeyBase: [KeyLayer],
        storedKeyOverrides: [String: KeyLayerOverride],
        keyTemplates: [String: KeyBinding],
        storedAppBase: [String: SpaceID],
        storedFloatBase: [String],
        storedFloatOverrides: [String: RuleListOverride],
        unreadable: [String],
        lensReach: [String: [String: Bool]] = [:]
    ) {
        self.appRules = appRules
        self.floatRules = floatRules
        self.keyLayers = keyLayers
        self.scrollGestures = scrollGestures
        self.storedScrollBase = storedScrollBase
        self.spaceHistory = spaceHistory
        self.modeCycle = modeCycle
        self.tileRules = tileRules
        self.floatAutomatically = floatAutomatically
        self.storedTileBase = storedTileBase
        self.storedTileOverrides = storedTileOverrides
        self.storedKeyBase = storedKeyBase
        self.storedKeyOverrides = storedKeyOverrides
        self.fileKeyBase = storedKeyBase
        self.fileKeyOverrides = storedKeyOverrides
        self.keyTemplates = keyTemplates
        self.storedAppBase = storedAppBase
        self.storedFloatBase = storedFloatBase
        self.storedFloatOverrides = storedFloatOverrides
        self.unreadable = unreadable
        self.lensReach = lensReach
        self.fileLensReach = lensReach
    }

    /// Whether a change reached any file.
    public var isEdited: Bool {
        !appRules.baseTouched.isEmpty || !floatRules.baseTouched.isEmpty
            || !keyLayers.baseTouched.isEmpty
            || !scrollGestures.baseTouched.isEmpty
            || !spaceHistory.baseTouched.isEmpty
            || !modeCycle.baseTouched.isEmpty
            || !tileRules.baseTouched.isEmpty
            || !floatAutomatically.baseTouched.isEmpty
            || !RuleReachTable<String>.sameShortcuts(keyBase, fileKeyBase)
            || storedKeyOverrides != fileKeyOverrides
            || appRules.touched.values.contains { !$0.isEmpty }
            || floatRules.touched.values.contains { !$0.isEmpty }
            || keyLayers.touched.values.contains { !$0.isEmpty }
            || scrollGestures.touched.values.contains { !$0.isEmpty }
            || spaceHistory.touched.values.contains { !$0.isEmpty }
            || modeCycle.touched.values.contains { !$0.isEmpty }
            || tileRules.touched.values.contains { !$0.isEmpty }
            || floatAutomatically.touched.values.contains { !$0.isEmpty }
            || lensReach != fileLensReach
    }

    /// The loaded page's gui.json layers, when the draft is that
    /// page (`keyLayerBase(page:)`) — set by the Settings draft so
    /// the rule write and the globals write read ONE base.
    public var pageKeyBase: [KeyLayer]?

    /// The base layers the key table now holds: the page's shape
    /// on the loaded page, else the stored base with each touched
    /// key rebuilt.
    public var keyBase: [KeyLayer] {
        pageKeyBase
            ?? keyLayers.keyLayerBase(
                original: storedKeyBase,
                templates: keyTemplates
            )
    }

    /// `profile`'s resolved layers as stored.
    public func storedKeyLayers(for profile: String) -> [KeyLayer] {
        storedKeyOverrides[profile]?.resolved(onto: storedKeyBase)
            ?? storedKeyBase
    }
}

extension KiwiCore {
    /// The shared rules and every profile's overrides, or nil
    /// where `gui.json` does not own the base (a hand-written
    /// `init.lua` authors it, so no shared write is possible).
    /// `reading` is a profile the caller already read, taken in place
    /// of a second read of its file.
    public func ruleReachSnapshot(
        reading live: Profile? = nil
    ) -> RuleReachSnapshot? {
        guard isGuiManaged, let sidecar = guiConfigStore.load() else {
            return nil
        }
        let stored = profiles.allProfiles().map { profile in
            live.flatMap { $0.name == profile.name ? $0 : nil } ?? profile
        }
        var floats: [String: RuleListOverride] = [:]
        var tiles: [String: RuleListOverride] = [:]
        var keys: [String: KeyLayerOverride] = [:]
        var templates: [String: KeyBinding] = [:]
        let keyBase = sidecar.layers
        // The base's own rows first, so a row the save writes takes
        // the shared label and kind over any one profile's.
        RuleReachTable<String>.collectTemplates(keyBase, into: &templates)
        for profile in stored {
            floats[profile.name] = profile.floatRules
            tiles[profile.name] = profile.tileRules
            keys[profile.name] = profile.layers
            RuleReachTable<String>.collectTemplates(
                profile.layers?.resolved(onto: keyBase) ?? keyBase,
                into: &templates
            )
        }
        return RuleReachSnapshot(
            appRules: .appRules(
                base: sidecar.appRules,
                overrides: stored.map { ($0.name, $0.appRules) }
            ),
            floatRules: .floatRules(
                base: sidecar.floatRules,
                overrides: stored.map { ($0.name, $0.floatRules) }
            ),
            keyLayers: .keyLayers(
                base: keyBase,
                overrides: stored.map { ($0.name, $0.layers) }
            ),
            scrollGestures: .scrollGestures(
                base: sidecar.scrollGesture,
                overrides: stored.map { ($0.name, $0.scrollGesture) }
            ),
            storedScrollBase: sidecar.scrollGesture,
            spaceHistory: .spaceHistory(
                base: sidecar.spaceHistory,
                overrides: stored.map { ($0.name, $0.spaceHistory) }
            ),
            modeCycle: .modeCycle(
                base: sidecar.modeCycle,
                overrides: stored.map { ($0.name, $0.modeCycle) }
            ),
            tileRules: .tileRules(
                base: sidecar.tileRules,
                overrides: stored.map { ($0.name, $0.tileRules) }
            ),
            floatAutomatically: .floatAutomatically(
                base: sidecar.floatAutomatically,
                overrides: stored.map { ($0.name, $0.floatAutomatically) }
            ),
            storedTileBase: sidecar.tileRules,
            storedTileOverrides: tiles,
            storedKeyBase: keyBase,
            storedKeyOverrides: keys,
            keyTemplates: templates,
            storedAppBase: sidecar.appRules,
            storedFloatBase: sidecar.floatRules,
            storedFloatOverrides: floats,
            unreadable: profiles.brokenProfiles().map(\.name),
            lensReach: Dictionary(
                uniqueKeysWithValues: stored.map {
                    ($0.name, $0.lensReach ?? [:])
                }
            )
        )
    }
}
