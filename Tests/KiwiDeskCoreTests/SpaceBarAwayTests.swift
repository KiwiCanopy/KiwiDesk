import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar draws the Desktop in front of the user (#1228):
/// a window KiwiDesk parked is its to draw, one sitting on
/// another macOS Desktop is macOS's and is absent — and
/// `hide_empty` drops a Space holding only away windows.
///
/// Every case asserts the row that REMAINS, not just the absence:
/// a suite expecting emptiness everywhere would pass on a bar
/// that drew nothing at all.
@MainActor
@Suite("Space Bar away members")
struct SpaceBarAwayTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        return core
    }

    private func window(_ id: UInt32, app: String = "Safari") -> ManagedWindow
    {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: app,
            appBundleID: "app.\(app.lowercased())"
        )
    }

    private func add(
        _ core: KiwiCore,
        _ id: UInt32,
        app: String = "Safari",
        to space: SpaceID
    ) {
        core.state.windows.upsert(window(id, app: app))
        core.state.workspaces.add(WindowID(id), to: space)
    }

    /// Files `id` as away in `space` at `rank`.
    private func park(
        _ core: KiwiCore,
        _ id: UInt32,
        app: String = "Safari",
        in space: SpaceID,
        rank: Int
    ) {
        core.state.awayWindows[WindowID(id)] = AwayWindow(
            id: WindowID(id),
            pid: 100,
            appName: app,
            appBundleID: "app.\(app.lowercased())",
            nativeSpace: 4
        )
        core.state.rememberedSpaces[WindowID(id)] = .departed(space)
        core.state.departedSlots[WindowID(id)] = rank
    }

    @Test("an away window is absent, its sibling draws")
    func awayAbsentSiblingDraws() {
        let core = makeCore()
        add(core, 1, to: "2")
        park(core, 7, in: "2", rank: 0)
        let (apps, overflow, _) = core.spaceBarApps(
            in: core.state.workspaces["2"]!,
            style: core.tiler.settings.spaceBarStyle
        )
        // Same app name: a merged away member would group with
        // the present one and read `count == 2` here.
        #expect(apps.map(\.name) == ["Safari"])
        #expect(apps.first?.count == 1)
        #expect(overflow == 0)
    }

    @Test("an away member never splits a present run")
    func awayNeverSplitsRun() {
        let core = makeCore()
        add(core, 1, to: "2")
        add(core, 3, to: "2")
        // The present pair must carry ranks too, or the merge
        // APPENDS and the split this case is named for cannot
        // happen (guard-prover, 2026-09-03).
        core.state.departedSlots[WindowID(1)] = 0
        core.state.departedSlots[WindowID(3)] = 2
        // Ranked BETWEEN the two, so a merge breaks the run into
        // Safari · Mail · Safari.
        park(core, 2, app: "Mail", in: "2", rank: 1)
        let (apps, _, _) = core.spaceBarApps(
            in: core.state.workspaces["2"]!,
            style: core.tiler.settings.spaceBarStyle
        )
        #expect(apps.map(\.name) == ["Safari"])
        #expect(apps.map(\.count) == [2])
    }

    @Test("hide_empty drops an all-away Space")
    func hideEmptyDrops() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("3")
        var style = core.tiler.settings.spaceBarStyle
        style.hideEmpty = true
        core.tiler.settings.spaceBarStyle = style
        let display = Display(
            id: DisplayID(1),
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        core.state.workspaces.upsertDisplay(display)
        for id in ["1", "2", "3"] as [SpaceID] {
            core.state.workspaces.assign(id, to: display.id)
        }
        add(core, 1, to: "2")
        park(core, 7, in: "3", rank: 0)
        // The ACTIVE Space is exempt from hide_empty whatever it
        // holds, so the pair that decides this case is 2 against
        // 3: 2 stays on its present window, 3 goes because all it
        // holds is on another Desktop. Asserting 1 alone would
        // pass on a bar that drew nothing (guard-prover,
        // 2026-09-03).
        let items = core.spaceBarItems(display: DisplayID(1), style: style)
        #expect(items.map(\.space) == ["1", "2"])
        #expect(
            items.first { $0.space == "2" }?.apps.map(\.name) == ["Safari"]
        )
    }
}
