import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 0, width: 1600, height: 1000)
private let ids = (1...3).map { WindowID(UInt32($0)) }

/// Hover focus under KiwiVision's maximize (#3177): the fill
/// follows the focus by ruling (#3064 point 6), so its own move is
/// no reason for the rest to stand down — a rest on a neighbour the
/// fill leaves in view focuses it and the fill follows.
@Suite("Hover focus moves KiwiVision's fill (#3177)", .serialized)
@MainActor
struct HoverFocusVisionFillTests {
    /// Three tiled BSP windows, the first focused and filled at
    /// `fill`, state frames where the pass sent them, the filled
    /// window in front.
    private func makeCore(fill: String) -> KiwiCore {
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
            args: [.string(space.raw), .string("bsp")]
        )
        core.focusWindow(ids[0], warp: false)
        core.execute("kiwivision.set_maximize", args: [.string(fill)])
        core.execute("kiwivision.toggle")
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
        let front = core.focusedWindowID
        let order = ids.sorted { a, _ in a == front }
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

    @Test(
        "A rest on a neighbour in view focuses it and moves the fill",
        arguments: ["height", "width"]
    )
    func restMovesTheFill(fill: String) throws {
        let core = makeCore(fill: fill)
        #expect(core.state.visionFill.drawn == [ids[0]])
        let neighbour = try #require(
            ids.dropFirst().first { shown(core, $0) != nil }
        )
        let point = try #require(shown(core, neighbour))
        #expect(core.hoverTarget(at: point)?.id == neighbour)
        core.focusUnderRestingPointer(
            at: GeometryUtils.axPoint(point),
            armedFocus: core.focusedWindowID
        )
        #expect(core.focusedWindowID == neighbour)
        #expect(core.state.visionFill.drawn == [neighbour])
    }
}

private func pid(_ id: WindowID) -> pid_t {
    pid_t(900_000 + Int(id.raw))
}
