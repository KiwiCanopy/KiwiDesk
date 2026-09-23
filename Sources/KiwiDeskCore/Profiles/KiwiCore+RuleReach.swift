import Foundation

/// The App Rules families across the shared base and every
/// readable profile (#1393), as the Settings checklist edits them.
public struct RuleReachSnapshot: Equatable, Sendable {
    public var appRules: RuleReachTable<SpaceID>
    public var floatRules: RuleReachTable<[String]>
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
        storedAppBase: [String: SpaceID],
        storedFloatBase: [String],
        storedFloatOverrides: [String: RuleListOverride],
        unreadable: [String]
    ) {
        self.appRules = appRules
        self.floatRules = floatRules
        self.storedAppBase = storedAppBase
        self.storedFloatBase = storedFloatBase
        self.storedFloatOverrides = storedFloatOverrides
        self.unreadable = unreadable
    }

    /// Whether a change reached any file.
    public var isEdited: Bool {
        !appRules.baseTouched.isEmpty || !floatRules.baseTouched.isEmpty
            || appRules.touched.values.contains { !$0.isEmpty }
            || floatRules.touched.values.contains { !$0.isEmpty }
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
        for profile in stored {
            floats[profile.name] = profile.floatRules
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
            storedAppBase: sidecar.appRules,
            storedFloatBase: sidecar.floatRules,
            storedFloatOverrides: floats,
            unreadable: profiles.brokenProfiles().map(\.name)
        )
    }

    /// Writes an edited snapshot: each profile the change reached,
    /// then the shared base, then re-resolves the live rules so
    /// the loaded profile's page is what the screen does. A
    /// profile the change did not reach is not rewritten.
    public func saveRuleReach(_ snapshot: RuleReachSnapshot) throws {
        guard snapshot.isEdited else { return }
        let app = snapshot.appRules
        let float = snapshot.floatRules
        for name in app.profiles {
            let original = snapshot.storedFloatOverrides[name]
            let floatOverride = float.floatRuleOverride(
                for: name,
                original: original
            )
            let appTouched = !(app.touched[name] ?? []).isEmpty
            guard appTouched || floatOverride != original else {
                continue
            }
            var profile = try profiles.read(name: name)
            if appTouched {
                profile.appRules = app.appRuleOverride(for: name)
            }
            profile.floatRules = floatOverride
            try profiles.write(profile)
        }
        if !app.baseTouched.isEmpty || !float.baseTouched.isEmpty {
            guard var sidecar = guiConfigStore.load() else {
                throw SidecarError.unreadable
            }
            sidecar.appRules = app.appRuleBase(
                original: snapshot.storedAppBase
            )
            sidecar.floatRules = float.floatRuleBase(
                original: snapshot.storedFloatBase
            )
            try guiConfigStore.save(sidecar)
        }
        refreshConfigIssues()
        refreshWindowRules()
    }
}
