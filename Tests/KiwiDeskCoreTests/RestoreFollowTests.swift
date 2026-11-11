import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile switch's restore that takes the focused window out of
/// the active Space and leaves it empty is followed (#3191 ▸
/// Ruling); one that leaves a window there moves no focus.
@Suite("A restore that empties the focused Space follows (#3191)")
@MainActor
struct RestoreFollowTests {
    private let w1 = WindowID(1)
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

    /// Under A, w1 lives in Space 2; under B it sits alone in
    /// Space 1, focused and active, with `stayer` beside it where
    /// given — a window A has never seen, which stays in Space 1.
    private func makeCore(stayer: WindowID? = nil) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-restorefollow-\(UUID().uuidString)"
                )
        )
        for id in [w1, w3] {
            core.state.windows.upsert(
                ManagedWindow(id: id, pid: 900_001, appName: "App")
            )
        }
        core.apply(profile: profile("A"), cause: .event)
        core.state.workspaces.add(w1, to: "2")
        core.apply(profile: profile("B"), cause: .event)
        core.state.workspaces.add(w1, to: "1")
        if let stayer { core.state.workspaces.add(stayer, to: "1") }
        core.state.workspaces.activate("1")
        core.state.workspaces.focus(w1, in: "1")
        return core
    }

    @Test("Emptying the active Space follows its focused window")
    func emptiedSpaceFollows() {
        let core = makeCore()
        #expect(core.state.workspaces.activeSpace == "1")
        core.apply(profile: profile("A"), cause: .event)
        #expect(core.state.workspaces.space(of: w1) == "2")
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.focusedWindowID == w1)
    }

    @Test("A window left behind keeps the user where they are")
    func stayerKeepsTheSpace() {
        let core = makeCore(stayer: w3)
        core.apply(profile: profile("A"), cause: .event)
        #expect(core.state.workspaces.space(of: w1) == "2")
        #expect(core.state.workspaces.space(of: w3) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
    }
}
