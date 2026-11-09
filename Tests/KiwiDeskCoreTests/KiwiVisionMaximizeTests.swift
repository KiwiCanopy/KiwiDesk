import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 0, width: 1600, height: 1000)
private let ids = (1...3).map { WindowID(UInt32($0)) }

/// Three tiled windows laid out in `mode`, the first focused, the
/// bars hidden, KiwiVision on and its maximize set to `fill`.
@MainActor
private func makeCore(
    fill: VisionMaximize = .full,
    mode: String = "bsp"
) -> (KiwiCore, SpaceID) {
    let core = makeTestCore(
        configDirectory:
            testTemporaryDirectory
            .appendingPathComponent("kiwi-vfill-\(UUID().uuidString)")
    )
    core.tiler.visibleBounds = { _ in bounds }
    core.tiler.settings.spaceBarStyle.visibility = .hidden
    core.tiler.settings.monocle.appBar.visibility = .hidden
    core.eventLoop.ownKeyWindow = { nil }
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
    core.execute("kiwivision.set_maximize", args: [.string(fill.rawValue)])
    core.execute("kiwivision.toggle")
    return (core, space)
}

@MainActor
private func filled(_ core: KiwiCore, _ space: SpaceID) -> WindowID? {
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

/// KiwiVision's maximize (#3064): derived each pass from KiwiVision
/// on, the option and the focused tiled window — it follows focus,
/// stands down on Monocle and floats, and a hand Maximize wins.
@Suite("KiwiVision maximize (#3064)", .serialized)
@MainActor
struct KiwiVisionMaximizeTests {
    @Test("On with Full, the focused window fills; the rest keep slots")
    func focusedFills() {
        let (core, space) = makeCore()
        #expect(filled(core, space) == ids[0])
        #expect(issued(core)[ids[0]] == bounds)
        #expect(issued(core)[ids[1]] == slots(core)[ids[1]])
        #expect(core.state.workspaces[space]?.maximized == nil)
    }

    @Test("The fill follows focus, a focus report included")
    func followsFocus() {
        let (core, space) = makeCore()
        core.focusWindow(ids[1], warp: false)
        #expect(filled(core, space) == ids[1])
        #expect(issued(core)[ids[1]] == bounds)
        #expect(issued(core)[ids[0]] == slots(core)[ids[0]])
        core.handle(.windowFocused(ids[2]))
        #expect(filled(core, space) == ids[2])
        #expect(issued(core)[ids[2]] == bounds)
    }

    @Test("A focus step names the window left and the one arriving")
    func stepNamesBoth() {
        let (core, space) = makeCore()
        core.state.workspaces.focus(ids[1], in: space)
        #expect(Set(core.retireEndedFills()) == [ids[0], ids[1]])
        #expect(core.retireEndedFills().isEmpty)
    }

    @Test("Off, KiwiVision off, Monocle or a float focus fill nothing")
    func standsDown() {
        let (core, space) = makeCore(fill: .off)
        #expect(filled(core, space) == nil)
        core.execute("kiwivision.set_maximize", args: [.string("full")])
        #expect(filled(core, space) == ids[0])
        core.execute("kiwivision.toggle")
        #expect(filled(core, space) == nil)
        #expect(issued(core)[ids[0]] == slots(core)[ids[0]])
        let (monocle, mSpace) = makeCore(mode: "monocle")
        #expect(filled(monocle, mSpace) == nil)
        let (floats, fSpace) = makeCore()
        floats.state.windows.setFloating(ids[2], true)
        floats.state.workspaces.focus(ids[2], in: fSpace)
        #expect(filled(floats, fSpace) == nil)
    }

    @Test("Height fills the height at the Layout Defaults share")
    func heightTakesTheShare() throws {
        let (core, space) = makeCore(fill: .height)
        let shape = try #require(
            core.state.workspaces[space].flatMap {
                core.state.maximizedShape(of: $0)
            }
        )
        #expect(shape.axis == .height)
        let rect = try #require(issued(core)[ids[0]])
        #expect(rect.height == bounds.height)
        #expect(rect.width < bounds.width)
    }

    @Test("A hand Maximize outranks it and its end hands back")
    func handOutranks() {
        let (core, space) = makeCore(fill: .height)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(core.state.workspaces[space]?.maximized != nil)
        #expect(issued(core)[ids[0]] == bounds)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(core.state.workspaces[space]?.maximized == nil)
        #expect(filled(core, space) == ids[0])
        #expect(issued(core)[ids[0]] != bounds)
    }

    @Test("A focus step retiles while the fill stands, on any layout")
    func focusRetiles() {
        let (core, _) = makeCore()
        #expect(core.focusRetiles(to: ids[1]))
        core.execute("kiwivision.toggle")
        #expect(!core.focusRetiles(to: ids[1]))
    }

    @Test("A fill change owes the plates one re-mask at the settle")
    func settleReshape() {
        let (core, space) = makeCore()
        core.vision.owesSettleReshape = false
        core.state.workspaces.focus(ids[1], in: space)
        _ = core.retireEndedFills()
        #expect(core.vision.owesSettleReshape)
        core.runBorderResync()
        #expect(!core.vision.owesSettleReshape)
    }
}
