import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Pins the #209 write-path asymmetry. The loaded profile is now
/// reachable through both save doors, and they touch disjoint
/// field sets *by design*: the Live-adopt save
/// (`persistProfile` / `buildProfile`) adopts only tiling and
/// MUST preserve the profile's sparse behavior overrides
/// overrides (Live editing changes the global base, not the
/// diff), while the override-row save (`overwriteProfile`)
/// rewrites those diffs — that half is covered by
/// `ProfileModesEditTests` / `ProfileAppRulesEditTests`. A
/// future edit that made the adopt path also write
/// those overrides would collapse the sparse diff into an
/// absolute and silently break overrides; these fail red first.
@Suite("Profile save-path asymmetry (#209)", .serialized)
@MainActor
struct ProfileSaveAsymmetryTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-asym-\(UUID().uuidString)"
                )
        )
        try? core.guiConfigStore.save(GuiConfig())
        return core
    }

    private var layersOverride: KeyLayerOverride {
        KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: "default",
                    bindings: [
                        KeyBinding(
                            combo: "alt+h",
                            lua: "OVERRIDE",
                            kind: .custom,
                            label: ""
                        )
                    ]
                )
            ]
        )
    }

    /// A one-display live setup matching a `["A:100x100"]` set,
    /// so `persistProfile`'s screen-count upsert succeeds.
    private func attachDisplay(_ core: KiwiCore) {
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
    }

    private func saveWork(
        _ core: KiwiCore,
        layers: KeyLayerOverride? = nil,
        appRules: AppRuleOverride? = nil,
        floatRules: RuleListOverride? = nil,
        ignoreRules: RuleListOverride? = nil
    ) throws {
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [:],
                settings: TilingSettings(),
                layers: layers,
                appRules: appRules,
                floatRules: floatRules,
                ignoreRules: ignoreRules
            )
        )
    }

    @Test("Live-adopt preserves the profile's layers override")
    func liveAdoptPreservesModes() throws {
        let core = makeCore()
        attachDisplay(core)
        try saveWork(core, layers: layersOverride)

        try core.persistProfile(named: "Work", modes: nil)

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.layers == layersOverride)
    }

    @Test("Live-adopt preserves the profile's app-rule override")
    func liveAdoptPreservesAppRules() throws {
        let core = makeCore()
        attachDisplay(core)
        let rules = AppRuleOverride(
            rules: ["Spotify": SpaceID("music")]
        )
        try saveWork(core, appRules: rules)

        try core.persistProfile(named: "Work", modes: nil)

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.appRules == rules)
    }

    @Test("Live-adopt preserves float and ignore overrides")
    func liveAdoptPreservesListRules() throws {
        let core = makeCore()
        attachDisplay(core)
        let floats = RuleListOverride(
            rules: ["Calculator": true]
        )
        let ignores = RuleListOverride(
            rules: ["Terminal": nil]
        )
        try saveWork(
            core,
            floatRules: floats,
            ignoreRules: ignores
        )

        try core.persistProfile(named: "Work", modes: nil)

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.floatRules == floats)
        #expect(saved.ignoreRules == ignores)
    }

    @Test("buildProfile never fabricates the override diffs")
    func buildProfileHasNoDiffs() {
        let core = makeCore()
        let built = core.buildProfile(name: "Work", modes: nil)
        #expect(built.layers == nil)
        #expect(built.appRules == nil)
        #expect(built.floatRules == nil)
        #expect(built.ignoreRules == nil)
    }
}
