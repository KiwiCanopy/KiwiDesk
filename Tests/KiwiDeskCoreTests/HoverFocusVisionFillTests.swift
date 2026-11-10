import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 0, width: 1600, height: 1000)
private let ids = (1...3).map { WindowID(UInt32($0)) }

/// Hover focus under a maximize that follows focus (#3177):
/// KiwiVision's fill (#3064 point 6) and a following hand Maximize
/// (#3063) re-point by ruling, so their own move is no reason for
/// the rest to stand down; a layout's own motion still is.
@Suite("Hover focus moves a following maximize (#3177)", .serialized)
@MainActor
struct HoverFocusVisionFillTests {
    /// Three tiled windows in `mode`, the first focused and filled
    /// at `fill` — by KiwiVision, or by a hand Maximize following
    /// focus as `hand` says — state frames where the pass sent
    /// them, the focused window in front.
    private func makeCore(
        fill: String,
        mode: String = "bsp",
        hand: Bool? = nil
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("hover-fill-\(UUID().uuidString)")
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
                        pid: pid(id),
                        appName: "App\(id.raw)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: ids[0])!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        if mode == "scrolling" {
            core.execute("scroll.set_slot_size", args: [.number(600)])
            core.execute("scroll.set_anchor", args: [.string("center")])
        }
        core.focusWindow(ids[0], warp: false)
        if let follow = hand {
            core.execute(
                "maximize.set_follow_focus",
                args: [.bool(follow)]
            )
            core.execute("toggle_maximized", args: [.string(fill)])
        } else {
            core.execute(
                "kiwivision.set_maximize",
                args: [.string(fill)]
            )
            core.execute("kiwivision.toggle")
        }
        core.tiler.settings.mouse.hoverFocus = true
        core.frontmostPIDProvider = { pid(ids[0]) }
        settle(core)
        return core
    }

    /// State frames and the front stack as the pass drew them,
    /// the focused window in front.
    private func settle(_ core: KiwiCore) {
        let placed = core.tiler.placedFrames(state: core.state)
        for (id, frame) in placed {
            core.state.apply(.windowMoved(id, frame))
        }
        let order =
            core.focusedWindowID.map { focused in
                [focused] + ids.filter { $0 != focused }
            } ?? ids
        core.frontStack = {
            order.map {
                KiwiCore.FrontWindow(
                    number: CGWindowID($0.raw),
                    pid: pid($0),
                    layer: 0,
                    frame: placed[$0]!
                )
            }
        }
    }

    /// A point on `id` the filled window leaves in view.
    private func shown(_ core: KiwiCore, _ id: WindowID) -> CGPoint? {
        let placed = core.tiler.placedFrames(state: core.state)
        guard let target = placed[id] else { return nil }
        let cover = placed[ids[0]] ?? .null
        for x in stride(from: target.minX + 5, to: target.maxX, by: 10) {
            for y in stride(from: target.minY + 5, to: target.maxY, by: 10)
            where !cover.contains(CGPoint(x: x, y: y)) {
                return CGPoint(x: x, y: y)
            }
        }
        return nil
    }

    /// A neighbour in view and a point on it.
    private func neighbourInView(
        _ core: KiwiCore
    ) throws -> (WindowID, CGPoint) {
        let neighbour = try #require(
            ids.dropFirst().first { shown(core, $0) != nil }
        )
        return (neighbour, try #require(shown(core, neighbour)))
    }

    /// Whether the copy the stand-down judges still holds a
    /// maximize that follows focus: the copy and the predicate are
    /// one list (#3177).
    private func copyStillFollows(_ core: KiwiCore) throws -> Bool {
        let space = try #require(core.activeSpace)
        let copy = core.state.droppingFocusFollowers(on: space.id)
        let held = try #require(copy.workspaces[space.id])
        return copy.maximizeFollowsFocus(on: held)
    }

    private func rest(_ core: KiwiCore, at point: CGPoint) {
        core.focusUnderRestingPointer(
            at: GeometryUtils.axPoint(point),
            armedFocus: core.focusedWindowID
        )
    }

    @Test(
        "A rest on a neighbour in view focuses it and moves the fill",
        arguments: ["height", "width"]
    )
    func restMovesTheFill(fill: String) throws {
        let core = makeCore(fill: fill)
        #expect(core.state.visionFill.drawn == [ids[0]])
        #expect(try !copyStillFollows(core))
        let (neighbour, point) = try neighbourInView(core)
        #expect(core.hoverTarget(at: point)?.id == neighbour)
        rest(core, at: point)
        #expect(core.focusedWindowID == neighbour)
        #expect(core.state.visionFill.drawn == [neighbour])
    }

    @Test(
        "A following hand Maximize moves; an ending one stands down",
        arguments: [true, false]
    )
    func handMaximize(follows: Bool) throws {
        let core = makeCore(fill: "height", hand: follows)
        let space = try #require(core.activeSpace)
        #expect(core.state.maximizedWindow(of: space) == ids[0])
        #expect(try !copyStillFollows(core))
        let (neighbour, point) = try neighbourInView(core)
        let target = core.hoverTarget(at: point)?.id
        #expect((target == neighbour) == follows)
        guard follows else { return }
        rest(core, at: point)
        let now = try #require(core.activeSpace)
        #expect(core.state.maximizedWindow(of: now) == neighbour)
    }

    /// The fill aside, a focus that pans the row still stands the
    /// rest down (#1869).
    @Test("A rest whose focus pans the row still stands down")
    func panStandsDown() throws {
        let core = makeCore(fill: "height", mode: "scrolling")
        #expect(core.state.visionFill.drawn == [ids[0]])
        let (_, point) = try neighbourInView(core)
        #expect(core.hoverTarget(at: point) == nil)
    }
}

private func pid(_ id: WindowID) -> pid_t {
    pid_t(900_000 + Int(id.raw))
}
