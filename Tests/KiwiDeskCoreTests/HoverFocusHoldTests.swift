import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pointer rest's hold (owner ruling 2026-10-17): after the
/// focus moves without the pointer — a shortcut, a new window, a
/// Space switch — the windows the pointer is left over are held,
/// and a rest on one stands down until a move leaves them all.
@Suite("Hover focus hold")
@MainActor
struct HoverFocusHoldTests {
    /// A rest whose windows are A left of x = 100 and B right of it.
    private func makeRest(focus: @escaping () -> WindowID?) -> PointerRest {
        let rest = PointerRest()
        rest.noteArm = focus
        rest.windowsAt = { point in
            [point.x < 100 ? WindowID(1) : WindowID(2)]
        }
        return rest
    }

    @Test("A focus moved without the pointer holds the window under it")
    func focusMoveHolds() {
        var focus = WindowID(1)
        let rest = makeRest { focus }
        rest.moved(to: CGPoint(x: 20, y: 10))
        rest.rest()
        #expect(rest.held.isEmpty, "a rest's own focus holds nothing")
        focus = WindowID(2)  // a shortcut moved it; pointer over A
        rest.moved(to: CGPoint(x: 30, y: 10))
        #expect(rest.held == [WindowID(1)])
        rest.moved(to: CGPoint(x: 50, y: 10))
        #expect(rest.held == [WindowID(1)], "still inside A")
        rest.moved(to: CGPoint(x: 150, y: 10))
        #expect(rest.held.isEmpty, "left A: released")
    }

    @Test("Turning it off drops the hold")
    func offDropsTheHold() {
        var focus = WindowID(1)
        let rest = makeRest { focus }
        rest.makeMonitor = { _ in NSObject() }
        rest.removeMonitor = { _ in }
        rest.setEnabled(true)
        rest.start()
        rest.moved(to: CGPoint(x: 20, y: 10))
        focus = WindowID(2)
        rest.moved(to: CGPoint(x: 30, y: 10))
        #expect(!rest.held.isEmpty)
        rest.setEnabled(false)
        #expect(rest.held.isEmpty)
    }

    /// The consumer half: a held window takes no hover focus, and
    /// the same rest focuses it once the hold is gone.
    @Test("A rest on a held window stands down")
    func heldWindowStandsDown() throws {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent("kiwidesk-hold-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for raw in [UInt32(1), 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "A\(raw)"
                    )
                )
            )
        }
        let space = try #require(core.activeSpace?.id)
        core.execute("set_mode", args: [.string(space.raw), .string("bsp")])
        core.focusWindow(WindowID(1), warp: false)
        let placed = core.tiler.placedFrames(state: core.state)
        for (id, frame) in placed {
            core.state.apply(.windowMoved(id, frame))
        }
        let stack = placed.sorted { $0.key.raw < $1.key.raw }.map {
            KiwiCore.FrontWindow(
                number: CGWindowID($0.key.raw),
                pid: 900_000 + pid_t($0.key.raw),
                layer: 0,
                frame: $0.value
            )
        }
        core.frontStack = { stack }
        core.tiler.settings.mouse.hoverFocus = true
        core.frontmostPIDProvider = { 900_001 }
        let w2 = try #require(core.state.windows[WindowID(2)]?.frame)
        let cocoa = GeometryUtils.axPoint(CGPoint(x: w2.midX, y: w2.midY))
        // The hold names w2: a first move learns the focus, then the
        // focus moves without the pointer and the next move holds.
        var focus = WindowID(1)
        core.mouse.rest.noteArm = { focus }
        core.mouse.rest.windowsAt = { _ in [WindowID(2)] }
        core.mouse.rest.moved(to: CGPoint(x: cocoa.x - 40, y: cocoa.y))
        focus = WindowID(9)
        core.mouse.rest.moved(to: cocoa)
        #expect(core.mouse.rest.held == [WindowID(2)])
        core.focusUnderRestingPointer(at: cocoa, armedFocus: WindowID(1))
        #expect(core.focusedWindowID == WindowID(1), "held: stands down")
        core.mouse.rest.windowsAt = { _ in [] }
        core.mouse.rest.moved(to: CGPoint(x: cocoa.x + 50, y: cocoa.y))
        #expect(core.mouse.rest.held.isEmpty)
        core.focusUnderRestingPointer(at: cocoa, armedFocus: WindowID(1))
        #expect(core.focusedWindowID == WindowID(2), "released: focuses")
    }
}
