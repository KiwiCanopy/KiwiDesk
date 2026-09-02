import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar draws a Space's away windows (#1146) under it,
/// by the rank they will return in, with the same glyph as a
/// present one — never the focus tint — and `hide_empty` keeps
/// a Space that holds only away windows.
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

    @Test("an away window draws under its Space")
    func awayDraws() {
        let core = makeCore()
        park(core, 7, in: "2", rank: 0)
        let space = core.state.workspaces["2"]!
        let (apps, overflow, _) = core.spaceBarApps(
            in: space,
            style: core.tiler.settings.spaceBarStyle
        )
        #expect(apps.map(\.name) == ["Safari"])
        #expect(apps.first?.count == 1)
        #expect(apps.first?.focused == false)
        #expect(overflow == 0)
    }

    @Test("an away window groups with an adjacent present one by rank")
    func awayGroupsByRank() {
        let core = makeCore()
        for id: UInt32 in [1, 3] {
            core.state.windows.upsert(window(id))
            core.state.workspaces.add(WindowID(id), to: "2")
        }
        core.state.departedSlots[WindowID(1)] = 0
        core.state.departedSlots[WindowID(3)] = 2
        park(core, 2, in: "2", rank: 1)
        park(core, 4, app: "Mail", in: "2", rank: 3)
        let space = core.state.workspaces["2"]!
        let (apps, _, _) = core.spaceBarApps(
            in: space,
            style: core.tiler.settings.spaceBarStyle
        )
        #expect(apps.map(\.name) == ["Safari", "Mail"])
        #expect(apps.map(\.count) == [3, 1])
    }

    @Test("hide_empty keeps a Space whose windows are all away")
    func hideEmptyKeeps() {
        let core = makeCore()
        var style = core.tiler.settings.spaceBarStyle
        style.hideEmpty = true
        core.tiler.settings.spaceBarStyle = style
        let display = Display(
            id: DisplayID(1),
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        core.state.workspaces.upsertDisplay(display)
        core.state.workspaces.assign(SpaceID("1"), to: display.id)
        core.state.workspaces.assign(SpaceID("2"), to: display.id)
        park(core, 7, in: "2", rank: 0)
        let items = core.spaceBarItems(display: DisplayID(1), style: style)
        #expect(items.map(\.space) == ["1", "2"])
        core.state.awayWindows[WindowID(7)] = nil
        let pruned = core.spaceBarItems(display: DisplayID(1), style: style)
        #expect(pruned.map(\.space) == ["1"])
    }

    @Test("an unfiled entry draws under no Space")
    func unfiledDrawsNowhere() {
        let core = makeCore()
        core.state.awayWindows[WindowID(7)] = AwayWindow(
            id: WindowID(7),
            pid: 100,
            appName: "Safari",
            appBundleID: "app.safari",
            nativeSpace: 4
        )
        for id in ["1", "2"] as [SpaceID] {
            let (apps, _, _) = core.spaceBarApps(
                in: core.state.workspaces[id]!,
                style: core.tiler.settings.spaceBarStyle
            )
            #expect(apps.isEmpty)
        }
    }
}
