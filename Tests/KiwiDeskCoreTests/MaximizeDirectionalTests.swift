import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 25, width: 1600, height: 1000)
private let space = SpaceID("1")
private let w1 = WindowID(1)
private let w2 = WindowID(2)

/// A bsp Space of two tiled windows on a pinned display, `w1`
/// focused, so `w1`'s slot is the left half.
@MainActor
private func makeCore() -> KiwiCore {
    let core = makeTestCore()
    core.tiler.visibleBounds = { _ in bounds }
    for id in [w1, w2] {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: id, pid: 900_001, appName: "A")
            )
        )
    }
    core.execute("set_mode", args: [.string("1"), .string("bsp")])
    core.state.workspaces.focus(w1, in: space)
    return core
}

@MainActor
private func issued(_ core: KiwiCore) -> [WindowID: CGRect] {
    core.tiler.placedFrames(state: core.state)
}

@MainActor
private func shape(_ core: KiwiCore) -> MaximizeShape? {
    core.state.workspaces[space].flatMap {
        core.state.maximizedShape(of: $0)
    }
}

/// `toggle_maximized(axis, share, anchor)` (#3062): one axis fills
/// the visible frame, the other takes the share, centred on the
/// screen or on the window's slot.
@Suite("Directional maximize (#3062)", .serialized)
@MainActor
struct MaximizeDirectionalTests {
    @Test("Height fills top to bottom at the stored share, centred")
    func heightCentred() {
        let core = makeCore()
        #expect(core.tiler.settings.maximize.heightShare == 0.5)
        #expect(
            core.execute("toggle_maximized", args: [.string("height")])
                .isSuccess
        )
        #expect(shape(core)?.axis == .height)
        #expect(
            issued(core)[w1]
                == CGRect(x: 400, y: 25, width: 800, height: 1000)
        )
    }

    @Test("Width fills side to side at a press's own share")
    func widthOwnShare() {
        let core = makeCore()
        core.execute(
            "toggle_maximized",
            args: [.string("width"), .number(0.75)]
        )
        #expect(
            issued(core)[w1]
                == CGRect(x: 0, y: 150, width: 1600, height: 750)
        )
    }

    @Test("In place centres on the slot and stays inside the screen")
    func inPlaceKeepsInside() {
        let core = makeCore()
        core.execute(
            "toggle_maximized",
            args: [.string("height"), .number(0.75), .string("in_place")]
        )
        // Centred on the left-half slot, the left edge would sit
        // off screen.
        #expect(
            issued(core)[w1]
                == CGRect(x: 0, y: 25, width: 1200, height: 1000)
        )
    }

    @Test("The stored anchor applies when a press names none")
    func storedAnchor() {
        let core = makeCore()
        core.execute("maximize.set_anchor", args: [.string("in_place")])
        core.execute(
            "maximize.set_share",
            args: [
                .string("height"), .number(0.25),
            ]
        )
        core.execute("toggle_maximized", args: [.string("height")])
        let frame = issued(core)[w1]
        #expect(frame?.width == 400)
        let slot = core.tiler.calculatedFrames(state: core.state)[w1]
        #expect(frame?.midX == slot?.midX)
    }

    @Test("Same shape ends it; another shape changes it in place")
    func pressSemantics() {
        let core = makeCore()
        core.execute("toggle_maximized", args: [.string("height")])
        core.execute("toggle_maximized")
        #expect(shape(core) == .full)
        #expect(issued(core)[w1] == bounds)
        core.execute("toggle_maximized")
        #expect(shape(core) == nil)
        #expect(
            issued(core)[w1]
                == core.tiler.calculatedFrames(state: core.state)[w1]
        )
    }

    @Test("A share or an axis out of range is refused")
    func refusals() {
        let core = makeCore()
        #expect(
            !core.execute("toggle_maximized", args: [.string("depth")])
                .isSuccess
        )
        #expect(
            !core.execute(
                "toggle_maximized",
                args: [.string("width"), .number(1.5)]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "maximize.set_share",
                args: [.string("width"), .number(0)]
            ).isSuccess
        )
        #expect(shape(core) == nil)
    }

    @Test("Only a fill reaching the shelf's strip stands it down")
    func reachIsGeometry() {
        let carved = CGRect(x: 0, y: 65, width: 1600, height: 960)
        #expect(
            KiwiCore.reachesShelf(
                CGRect(x: 400, y: 25, width: 800, height: 1000),
                layoutBounds: carved
            )
        )
        #expect(
            !KiwiCore.reachesShelf(
                CGRect(x: 0, y: 170, width: 1600, height: 750),
                layoutBounds: carved
            )
        )
        #expect(
            !KiwiCore.reachesShelf(
                CGRect(x: 0, y: 64.5, width: 1600, height: 960.5),
                layoutBounds: carved
            )
        )
    }
}
