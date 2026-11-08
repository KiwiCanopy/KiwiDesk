import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 0, width: 1600, height: 1000)
private let ids = (1...4).map { WindowID(UInt32($0)) }

/// A Space of four tiled windows laid out in `mode`, the first
/// focused, the bars hidden, `maximize.set_follow_focus` as `follow`.
@MainActor
private func makeCore(
    follow: Bool,
    mode: String = "grid"
) -> (KiwiCore, SpaceID) {
    let core = makeTestCore(
        configDirectory:
            testTemporaryDirectory
            .appendingPathComponent("kiwi-follow-\(UUID().uuidString)")
    )
    core.tiler.visibleBounds = { _ in bounds }
    core.tiler.settings.spaceBarStyle.visibility = .hidden
    core.tiler.settings.monocle.appBar.visibility = .hidden
    core.execute("set_focus_wrap", args: [.string("off")])
    for id in ids {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: pid_t(900_000 + Int(id.raw)),
                    appName: "App\(id.raw)"
                )
            )
        )
    }
    let space = core.state.workspaces.space(of: ids[0])!
    core.execute("set_mode", args: [.string(space.raw), .string(mode)])
    core.state.workspaces.focus(ids[0], in: space)
    core.execute("maximize.set_follow_focus", args: [.bool(follow)])
    return (core, space)
}

@MainActor
private func maximized(_ core: KiwiCore, _ space: SpaceID) -> WindowID? {
    core.state.workspaces[space].flatMap {
        core.state.maximizedWindow(of: $0)
    }
}

@MainActor
private func issued(_ core: KiwiCore) -> [WindowID: CGRect] {
    core.tiler.placedFrames(state: core.state)
}

@MainActor
private func slots(_ core: KiwiCore) -> [WindowID: CGRect] {
    core.tiler.calculatedFrames(state: core.state)
}

/// A Maximize that follows focus (#3063): stamped at the make, it
/// re-points at the tiled window focus lands on, the rest keep their
/// slots, and a Monocle draws a full one through #2976's transform.
@Suite("Maximize follows focus (#3063)", .serialized)
@MainActor
struct MaximizeFollowTests {
    @Test("By default a focus change still ends it")
    func defaultEnds() {
        let (core, space) = makeCore(follow: false)
        #expect(core.execute("toggle_maximized").isSuccess)
        core.focusWindow(ids[1], warp: false)
        #expect(maximized(core, space) == nil)
        #expect(issued(core)[ids[0]] == slots(core)[ids[0]])
    }

    @Test("A follow moves to the window focused; the left one returns")
    func followMoves() {
        let (core, space) = makeCore(follow: true)
        #expect(core.execute("toggle_maximized").isSuccess)
        core.focusWindow(ids[1], warp: false)
        #expect(maximized(core, space) == ids[1])
        #expect(issued(core)[ids[1]] == bounds)
        #expect(issued(core)[ids[0]] == slots(core)[ids[0]])
        #expect(slots(core)[ids[1]] != bounds)
    }

    @Test("A focus report on a static layout draws the follow")
    func focusReportDrawsTheFollow() {
        let (core, space) = makeCore(follow: true, mode: "bsp")
        #expect(core.execute("toggle_maximized").isSuccess)
        core.handle(.windowFocused(ids[1]))
        #expect(maximized(core, space) == ids[1])
        #expect(issued(core)[ids[1]] == bounds)
        #expect(issued(core)[ids[0]] == slots(core)[ids[0]])
    }

    @Test("A float taking focus keeps the follow where it is")
    func floatFocusKeeps() {
        let (core, space) = makeCore(follow: true)
        core.execute("toggle_maximized")
        core.state.windows.setFloating(ids[3], true)
        core.state.workspaces.focus(ids[3], in: space)
        core.state.retireEndedMaximize()
        #expect(maximized(core, space) == ids[0])
    }

    @Test("Focus search reads the slots: up from bottom-left")
    func focusSearchReadsTheSlots() throws {
        let (core, space) = makeCore(follow: true)
        let slot = slots(core)
        let bottomLeft = try #require(
            ids.min {
                (slot[$0]?.minX ?? 0, -(slot[$0]?.minY ?? 0)) < (
                    slot[$1]?.minX ?? 0, -(slot[$1]?.minY ?? 0)
                )
            }
        )
        let topLeft = try #require(
            ids.min {
                (slot[$0]?.minX ?? 0, slot[$0]?.minY ?? 0) < (
                    slot[$1]?.minX ?? 0, slot[$1]?.minY ?? 0
                )
            }
        )
        #expect(bottomLeft != topLeft)
        core.state.workspaces.focus(bottomLeft, in: space)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(core.execute("focus", args: [.string("up")]).isSuccess)
        #expect(maximized(core, space) == topLeft)
    }

    @Test("The switch is stamped at the make, never read live")
    func stampedAtTheMake() {
        let (core, space) = makeCore(follow: true)
        core.execute("toggle_maximized")
        core.execute("maximize.set_follow_focus", args: [.bool(false)])
        core.focusWindow(ids[1], warp: false)
        #expect(maximized(core, space) == ids[1])

        let (off, offSpace) = makeCore(follow: false)
        off.execute("toggle_maximized")
        off.execute("maximize.set_follow_focus", args: [.bool(true)])
        off.focusWindow(ids[1], warp: false)
        #expect(maximized(off, offSpace) == nil)
    }

    @Test("A Height Maximize follows with its shape")
    func shapeFollows() {
        let (core, space) = makeCore(follow: true)
        core.execute("toggle_maximized", args: [.string("height")])
        core.focusWindow(ids[1], warp: false)
        #expect(maximized(core, space) == ids[1])
        let model = core.state.workspaces[space]!
        #expect(core.state.maximizedShape(of: model)?.axis == .height)
    }

    @Test("The retire names both windows of a re-point")
    func retireNamesBoth() {
        let (core, space) = makeCore(follow: true)
        core.execute("toggle_maximized")
        core.state.workspaces.focus(ids[2], in: space)
        let changed = core.state.retireEndedMaximize()
        #expect(Set(changed) == [ids[0], ids[2]])
        #expect(core.state.workspaces[space]?.maximized?.window == ids[2])
    }

    @Test("A window leaving the tiled set takes no follow")
    func leavingTakesNoFollow() {
        let (core, space) = makeCore(follow: true)
        core.execute("toggle_maximized")
        core.state.apply(.windowDestroyed(ids[0], wasMinimized: false))
        core.retile()
        // The destroy may be a Desktop departure, so the stored value
        // waits for the return (#2448); it never moves to a neighbour.
        #expect(maximized(core, space) == nil)
        let stored = core.state.workspaces[space]?.maximized?.window
        #expect(stored == nil || stored == ids[0])
    }

    @Test("A focus retiles while a follow stands, and not otherwise")
    func focusRetilesWhileFollowing() {
        let (core, _) = makeCore(follow: true, mode: "bsp")
        #expect(!core.focusRetiles(to: ids[1]))
        core.execute("toggle_maximized")
        #expect(core.focusRetiles(to: ids[1]))
    }

    @Test("On Monocle a full follow draws every member full")
    func monocleDrawsEveryMemberFull() {
        let (core, space) = makeCore(follow: true, mode: "monocle")
        // A shown, reserving bar: the layout bounds then differ from
        // the visible frame the follow draws over.
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.spaceBarStyle.reserve = true
        #expect(
            core.tiler.settings.layoutBounds(
                from: bounds,
                mode: .monocle,
                on: nil,
                pocketAtRest: false
            ) != bounds
        )
        core.execute("toggle_maximized")
        let before = issued(core)
        for id in ids { #expect(before[id] == bounds) }
        core.focusWindow(ids[1], warp: false)
        #expect(maximized(core, space) == ids[1])
        #expect(issued(core) == before)
    }
}
