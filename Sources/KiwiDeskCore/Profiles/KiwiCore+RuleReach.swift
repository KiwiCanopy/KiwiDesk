import Foundation

/// The App Rules families across the shared base and every
/// readable profile (#1393), as the Settings checklist edits them.
public struct RuleReachSnapshot: Equatable, Sendable {
    public var appRules: RuleReachTable<SpaceID>
    public var floatRules: RuleReachTable<[String]>
    /// Shortcuts, one action per layer (#1393's second half).
    public var keyLayers: RuleReachTable<String>
    public let storedKeyBase: [KeyLayer]
    public let storedKeyOverrides: [String: KeyLayerOverride]
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

    public init(
        appRules: RuleReachTable<SpaceID>,
        floatRules: RuleReachTable<[String]>,
        keyLayers: RuleReachTable<String>,
        storedKeyBase: [KeyLayer],
        storedKeyOverrides: [String: KeyLayerOverride],
        keyTemplates: [String: KeyBinding],
        storedAppBase: [String: SpaceID],
        storedFloatBase: [String],
        storedFloatOverrides: [String: RuleListOverride],
        unreadable: [String]
    ) {
        self.appRules = appRules
        self.floatRules = floatRules
        self.keyLayers = keyLayers
        self.storedKeyBase = storedKeyBase
        self.storedKeyOverrides = storedKeyOverrides
        self.keyTemplates = keyTemplates
        self.storedAppBase = storedAppBase
        self.storedFloatBase = storedFloatBase
        self.storedFloatOverrides = storedFloatOverrides
        self.unreadable = unreadable
    }

    /// Whether a change reached any file.
    public var isEdited: Bool {
        !appRules.baseTouched.isEmpty || !floatRules.baseTouched.isEmpty
            || !keyLayers.baseTouched.isEmpty
            || (pageKeyBase.map {
                !RuleReachTable<String>.sameShortcuts($0, storedKeyBase)
            } ?? false)
            || appRules.touched.values.contains { !$0.isEmpty }
            || floatRules.touched.values.contains { !$0.isEmpty }
            || keyLayers.touched.values.contains { !$0.isEmpty }
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
    public func ruleReachSnapshot() -> RuleReachSnapshot? {
        guard isGuiManaged, let sidecar = guiConfigStore.load() else {
            return nil
        }
        let stored = profiles.allProfiles()
        var floats: [String: RuleListOverride] = [:]
        var keys: [String: KeyLayerOverride] = [:]
        var templates: [String: KeyBinding] = [:]
        let keyBase = sidecar.layers
        // The base's own rows first, so a row the save writes takes
        // the shared label and kind over any one profile's.
        RuleReachTable<String>.collectTemplates(keyBase, into: &templates)
        for profile in stored {
            floats[profile.name] = profile.floatRules
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
            storedKeyBase: keyBase,
            storedKeyOverrides: keys,
            keyTemplates: templates,
            storedAppBase: sidecar.appRules,
            storedFloatBase: sidecar.floatRules,
            storedFloatOverrides: floats,
            unreadable: profiles.brokenProfiles().map(\.name)
        )
    }

    /// Writes an edited snapshot: each profile the change reached,
    /// then the shared base, then re-resolves the live rules so
    /// the loaded profile's page is what the screen does. A
    /// profile the change did not reach is not rewritten. Every
    /// reached file and the base are read and encoded before any
    /// write, so an unreadable one refuses the whole write rather
    /// than half of it.
    ///
    /// `keysLeftTo` names the stored profile whose shortcut override
    /// its own Save diffs from the page (`overwriteProfile`), which
    /// carries its layer structure too; its keys are skipped here.
    public func saveRuleReach(
        _ snapshot: RuleReachSnapshot,
        keysLeftTo page: String? = nil
    ) throws {
        guard snapshot.isEdited else { return }
        let app = snapshot.appRules
        let float = snapshot.floatRules
        var pending: [Profile] = []
        for name in app.profiles {
            let original = snapshot.storedFloatOverrides[name]
            let floatOverride = float.floatRuleOverride(
                for: name,
                original: original
            )
            let appTouched = !(app.touched[name] ?? []).isEmpty
            let keyTouched =
                name != page
                && !(snapshot.keyLayers.touched[name] ?? []).isEmpty
            guard appTouched || keyTouched || floatOverride != original
            else { continue }
            var profile = try profiles.read(name: name)
            if appTouched {
                profile.appRules = app.appRuleOverride(for: name)
            }
            if keyTouched {
                profile.layers = snapshot.keyLayers.keyLayerOverride(
                    for: name,
                    original: snapshot.storedKeyOverrides[name],
                    newBase: snapshot.keyBase,
                    templates: snapshot.keyTemplates
                )
            }
            profile.floatRules = floatOverride
            pending.append(profile)
        }
        var sidecar: GuiConfig?
        let keysMoved =
            !snapshot.keyLayers.baseTouched.isEmpty
            || !RuleReachTable<String>.sameShortcuts(
                snapshot.keyBase,
                snapshot.storedKeyBase
            )
        if !app.baseTouched.isEmpty || !float.baseTouched.isEmpty
            || keysMoved
        {
            guard var stored = guiConfigStore.load() else {
                throw SidecarError.unreadable
            }
            stored.appRules = app.appRuleBase(
                original: snapshot.storedAppBase
            )
            stored.floatRules = float.floatRuleBase(
                original: snapshot.storedFloatBase
            )
            stored.layers = snapshot.keyBase
            sidecar = stored
        }
        for profile in pending { try profiles.write(profile) }
        if let sidecar { try guiConfigStore.save(sidecar) }
        refreshConfigIssues()
        refreshStructuredOverrides(
            keys: keysMoved
                || snapshot.keyLayers.touched.values.contains { !$0.isEmpty }
        )
    }
}
