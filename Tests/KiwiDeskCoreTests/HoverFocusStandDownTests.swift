import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Hover focus's stand-downs (#1869) beyond the hit test: a focus
/// that would move a window under the resting hand, a focus moved
/// during the dwell, the OS's own front app, full screen, the
/// Desktop settle and KiwiDesk's own window. Frames come from the
/// layout's own `placedFrames`, so a stand-down reads what the
/// engine would draw rather than a hand-written frame.
@Suite("Hover focus stand-downs (#1869)", .serialized)
@MainActor
struct HoverFocusStandDownTests {
    /// Two tiled windows laid out in `mode`, w1 focused, hover on,
    /// state and the front stack agreeing with the layout.
    private func makeCore(
        _ mode: String = "bsp",
        _ setup: (KiwiCore) -> Void = { _ in }
    ) throws -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-hover-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for raw in [UInt32(1), 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 10 + pid_t(raw),
                        appName: "A\(raw)"
                    )
                )
            )
        }
        let space = try #require(core.activeSpace?.id)
        core.execute("set_mode", args: [.string(space.raw), .string(mode)])
        setup(core)
        core.focusWindow(WindowID(1), warp: false)
        settle(core)
        core.tiler.settings.mouse.hoverFocus = true
        core.frontmostPIDProvider = { 11 }
        return core
    }

    /// Writes the layout's frames into state and the front stack.
    private func settle(_ core: KiwiCore) {
        let placed = core.tiler.placedFrames(state: core.state)
        for (id, frame) in placed {
            core.state.apply(.windowMoved(id, frame))
        }
        core.frontStack = {
            placed.sorted { $0.key.raw < $1.key.raw }.map {
                listed(
                    number: Int($0.key.raw),
                    pid: 10 + pid_t($0.key.raw),
                    frame: $0.value
                )
            }
        }
    }

    /// A point inside w2's on-screen part.
    private func overW2(_ core: KiwiCore) throws -> CGPoint {
        let frame = try #require(core.state.windows[WindowID(2)]?.frame)
        let shown = frame.intersection(
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        )
        try #require(!shown.isEmpty)
        return CGPoint(x: shown.midX, y: shown.midY)
    }

    @Test("A static layout reaches its neighbour")
    func staticLayoutReaches() throws {
        let core = try makeCore()
        #expect(core.hoverTarget(at: try overW2(core))?.id == WindowID(2))
    }

    @Test("A focus that re-seats the scrolling row stands down")
    func reseatingAnchorStandsDown() throws {
        let follow = try makeCore("scrolling") {
            $0.execute("scroll.set_slot_size", args: [.number(700)])
        }
        #expect(
            follow.hoverTarget(at: try overW2(follow))?.id == WindowID(2),
            "follow keeps a shown slot still"
        )
        let center = try makeCore("scrolling") {
            $0.execute("scroll.set_slot_size", args: [.number(700)])
            $0.execute("scroll.set_anchor", args: [.string("center")])
        }
        #expect(center.hoverTarget(at: try overW2(center)) == nil)
    }

    @Test("A peeking scrolling slot stands down")
    func peekingSlotStandsDown() throws {
        let core = try makeCore("scrolling") {
            $0.execute("scroll.set_slot_size", args: [.number(1200)])
        }
        #expect(core.hoverTarget(at: try overW2(core)) == nil)
    }

    @Test("A focus moved during the dwell stands")
    func movedFocusStands() throws {
        let core = try makeCore()
        let point = GeometryUtils.axPoint(try overW2(core))
        core.focusUnderRestingPointer(at: point, armedFocus: WindowID(2))
        #expect(core.focusedWindowID == WindowID(1))
        core.focusUnderRestingPointer(at: point, armedFocus: WindowID(1))
        #expect(core.focusedWindowID == WindowID(2))
    }

    @Test("A rest just after a Desktop switch stands down")
    func desktopSettleStandsDown() throws {
        let core = try makeCore()
        let point = GeometryUtils.axPoint(try overW2(core))
        core.lastDesktopSwitch = core.wallClock()
        core.focusUnderRestingPointer(at: point, armedFocus: WindowID(1))
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("The focused window is still reached while its app is not")
    func focusedButNotFrontIsReached() throws {
        let core = try makeCore()
        let overW1 = CGPoint(x: 20, y: 400)
        #expect(core.hoverTarget(at: overW1) == nil)
        core.frontmostPIDProvider = { 99 }
        #expect(core.hoverTarget(at: overW1)?.id == WindowID(1))
    }

    @Test("A full-screen window stands down")
    func fullscreenStandsDown() throws {
        let core = try makeCore()
        let point = try overW2(core)
        core.state.apply(
            .windowFullscreenChanged(WindowID(2), isFullscreen: true)
        )
        #expect(core.hoverTarget(at: point) == nil)
    }

    /// KiwiDesk's chrome (a bar, a panel) is untracked and stands
    /// hover down; its tracked Settings window is a target, flagged
    /// own so its raise takes the GUI's door.
    @Test("Own chrome stands down; the own tracked window is a target")
    func ownWindowIsTargetOnlyWhenTracked() throws {
        let core = try makeCore()
        let point = try overW2(core)
        let below = core.frontStack()
        core.frontStack = {
            [listed(number: 99, pid: getpid(), frame: below[1].frame)]
                + below
        }
        #expect(core.hoverTarget(at: point) == nil)
        core.frontStack = {
            [listed(number: 2, pid: getpid(), frame: below[1].frame)]
                + below
        }
        let target = try #require(core.hoverTarget(at: point))
        #expect(target.id == WindowID(2))
        #expect(target.own)
    }

    /// The Settings window is raised through the open-or-raise
    /// door, never a bare focus (#1281); another window never
    /// reaches it.
    @Test("Hover onto Settings takes the Settings door")
    func settingsTakesItsDoor() throws {
        let core = try makeCore()
        var opened = 0
        core.uiBridge.onOpenSettings = { opened += 1 }
        let point = try overW2(core)
        let ax = GeometryUtils.axPoint(point)
        core.focusUnderRestingPointer(at: ax, armedFocus: WindowID(1))
        #expect(opened == 0, "another app's window is focused directly")
        #expect(core.focusedWindowID == WindowID(2))
        core.focusWindow(WindowID(1), warp: false)
        let below = core.frontStack()
        core.frontStack = {
            [listed(number: 2, pid: getpid(), frame: below[1].frame)]
                + below
        }
        core.focusUnderRestingPointer(at: ax, armedFocus: WindowID(1))
        #expect(opened == 1)
        #expect(core.focusedWindowID == WindowID(1), "no bare focus")
    }

    /// A hotkey pressed while the hovered app is still coming
    /// forward passes the #292 preflight as the `focus` verb's
    /// does: the hover records the app it left (#1812).
    @Test("A hover records the raise flight it started")
    func hoverRecordsAFlight() throws {
        let core = try makeCore()
        let point = GeometryUtils.axPoint(try overW2(core))
        // The front app turns over once the focus runs: the flight
        // names the one read BEFORE it.
        core.frontmostPIDProvider = { [weak core] in
            core?.focusedWindowID == WindowID(2) ? 12 : 11
        }
        core.focusUnderRestingPointer(at: point, armedFocus: WindowID(1))
        let flight = try #require(core.raiseFlight)
        #expect(flight.target == WindowID(2))
        #expect(flight.leftPID == 11)
    }

    /// The focused window under the pointer while another app is
    /// in front is reached, and moves no focus: no flight.
    @Test("A hover that moves no focus records no flight")
    func sameFocusRecordsNoFlight() throws {
        let core = try makeCore()
        core.frontmostPIDProvider = { 99 }
        core.focusUnderRestingPointer(
            at: GeometryUtils.axPoint(CGPoint(x: 20, y: 400)),
            armedFocus: WindowID(1)
        )
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.raiseFlight == nil)
    }
}

/// One front-to-back row (#1869); the fields a fixture leaves out
/// are the defaults no stand-down reads.
private func listed(
    number: Int = 0,
    pid: pid_t = 0,
    layer: Int = 0,
    frame: CGRect
) -> KiwiCore.FrontWindow {
    KiwiCore.FrontWindow(
        number: CGWindowID(number),
        pid: pid,
        layer: layer,
        frame: frame
    )
}
