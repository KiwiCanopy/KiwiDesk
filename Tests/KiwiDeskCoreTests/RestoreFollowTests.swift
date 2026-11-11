import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile switch's restore that takes the focused window out of
/// the active Space and leaves it empty is followed (#3191 ▸
/// Ruling), through both apply doors and every cause but the
/// Desktop switch's, whose handler activates its own Space; one
/// that leaves a window there moves no focus.
@Suite("A restore that empties the focused Space follows (#3191)")
@MainActor
struct RestoreFollowTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [],
            spaces: ["1", "2"],
            spaceModes: ["1": .bsp, "2": .bsp],
            settings: TilingSettings()
        )
    }

    private let standard = ProfileComposition.Composed(
        sourceName: "Docked",
        spaces: ["1", "2"],
        spaceModes: ["1": .bsp, "2": .bsp],
        assignment: [:],
        settings: TilingSettings(),
        sourceTitle: nil
    )

    private enum Home { case profileA, standard }

    private func applyHome(
        _ core: KiwiCore,
        _ home: Home,
        cause: ProfileApplyCause = .monitorChange
    ) {
        switch home {
        case .profileA:
            core.apply(profile: profile("A"), cause: cause)
        case .standard:
            core.apply(composed: standard, forceRetile: false)
        }
    }

    /// Under `home`, w1 and w2 live in Space 2, w2 focused there,
    /// so a focus landing on w1 is the follow's, not the Space's
    /// own. Under B, w1 sits alone in Space 1, focused and active,
    /// with `stayer` beside it where given — a window `home` has
    /// never seen, which stays in Space 1.
    private func makeCore(
        home: Home = .profileA,
        stayer: WindowID? = nil
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-restorefollow-\(UUID().uuidString)"
                )
        )
        for id in [w1, w2, w3] {
            core.state.windows.upsert(
                ManagedWindow(id: id, pid: 900_001, appName: "App")
            )
        }
        applyHome(core, home)
        core.state.workspaces.add(w1, to: "2")
        core.state.workspaces.add(w2, to: "2")
        core.state.workspaces.focus(w2, in: "2")
        core.apply(profile: profile("B"), cause: .event)
        core.state.workspaces.add(w1, to: "1")
        if let stayer { core.state.workspaces.add(stayer, to: "1") }
        core.state.workspaces.activate("1")
        core.state.workspaces.focus(w1, in: "1")
        return core
    }

    @Test(
        "Emptying the active Space follows its focused window",
        arguments: [ProfileApplyCause.monitorChange, .explicit, .event]
    )
    func emptiedSpaceFollows(cause: ProfileApplyCause) {
        let core = makeCore()
        #expect(core.state.workspaces.activeSpace == "1")
        applyHome(core, .profileA, cause: cause)
        #expect(core.state.workspaces.space(of: w1) == "2")
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.focusedWindowID == w1)
    }

    @Test("A composed Standard's restore follows the same way")
    func standardFollows() {
        let core = makeCore(home: .standard)
        applyHome(core, .standard)
        #expect(core.state.workspaces.space(of: w1) == "2")
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.focusedWindowID == w1)
    }

    @Test("A window left behind keeps the user where they are")
    func stayerKeepsTheSpace() {
        let core = makeCore(stayer: w3)
        applyHome(core, .profileA)
        #expect(core.state.workspaces.space(of: w1) == "2")
        #expect(core.state.workspaces.space(of: w3) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
    }

    /// The switch handler activates the arriving Space itself.
    @Test("A bound Desktop switch's apply follows nothing")
    func boundDesktopSwitchStandsDown() {
        let core = makeCore()
        applyHome(core, .profileA, cause: .desktopSwitch)
        #expect(core.state.workspaces.space(of: w1) == "2")
        #expect(core.state.workspaces.activeSpace == "1")
    }
}
