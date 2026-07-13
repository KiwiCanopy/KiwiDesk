import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Pins the #209 write-path asymmetry. The loaded profile is now
/// reachable through both save doors, and they touch disjoint
/// field sets *by design*: the Live-adopt save
/// (`persistProfile` / `buildProfile`) adopts only tiling and
/// MUST preserve the profile's sparse `modes` / `appRules`
/// overrides (Live editing changes the global base, not the
/// diff), while the override-row save (`overwriteProfile`)
/// rewrites those diffs — that half is covered by
/// `ProfileModesEditTests` / `ProfileAppRulesEditTests`. A
/// future edit that made the adopt path also write
/// `modes`/`appRules` would collapse the sparse diff into an
/// absolute and silently break overrides; these fail red first.
@Suite("Profile save-path asymmetry (#209)", .serialized)
@MainActor
struct ProfileSaveAsymmetryTests {
    private func makeCore() -> KiwiCore {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-asym-\(UUID().uuidString)"
                )
        )
        try? core.guiConfigStore.save(GuiConfig())
        return core
    }

    private var modesOverride: KeyModeOverride {
        KeyModeOverride(
            modes: [
                KeyMode(
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
        modes: KeyModeOverride? = nil,
        appRules: AppRuleOverride? = nil
    ) throws {
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [:],
                settings: TilingSettings(),
                modes: modes,
                appRules: appRules
            )
        )
    }

    @Test("Live-adopt preserves the profile's modes override")
    func liveAdoptPreservesModes() throws {
        let core = makeCore()
        attachDisplay(core)
        try saveWork(core, modes: modesOverride)

        try core.persistProfile(named: "Work")

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.modes == modesOverride)
    }

    @Test("Live-adopt preserves the profile's app-rule override")
    func liveAdoptPreservesAppRules() throws {
        let core = makeCore()
        attachDisplay(core)
        let rules = AppRuleOverride(
            rules: ["Spotify": SpaceID("music")]
        )
        try saveWork(core, appRules: rules)

        try core.persistProfile(named: "Work")

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.appRules == rules)
    }

    @Test("buildProfile never fabricates the override diffs")
    func buildProfileHasNoDiffs() {
        let core = makeCore()
        let built = core.buildProfile(name: "Work")
        #expect(built.modes == nil)
        #expect(built.appRules == nil)
    }
}
