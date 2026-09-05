import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-warp-hold-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    // Pin the display (tests.md / #531): these tests resolve
    // the focused window's slot, which must not be the host's
    // screen.
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

/// The #689 warp hold: a mouse-follows-focus warp landing while
/// a z-order restore drains is HELD and re-fired at the last
/// drain's end — clickless intent only, staleness-checked — and
/// mouse-made focus (a click, a bar click near a fresh press)
/// never warps late. Split from `MouseFollowsFocusTests` (the
/// 350-line ceiling); that suite keeps the toggle, eligibility
/// and pure-geometry pins.
@Suite("Mouse warp hold (#689)", .serialized)
@MainActor
struct MouseWarpHoldTests {
    /// #689: a restore in flight used to DROP the warp — since
    /// #684 stretched a drain from ~10 ms to 50-400 ms, a focus
    /// change landing inside one routinely lost its warp with
    /// nothing re-issuing it. Held warps now re-fire when the
    /// last drain ends, staleness-checked.
    @Test("A restore in flight holds the warp, then re-fires it")
    func heldWarpRefiresOnDrainEnd() {
        // Slot resolution needs a real screen; a screenless
        // runner must skip, not red (the screen-guard
        // convention).
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.tiler.settings.mouse.followsFocus = true
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "A",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 400,
                        height: 300
                    )
                )
            )
        )
        let id = WindowID(1)
        let space = core.state.workspaces.space(of: id)!
        core.state.workspaces.focus(id, in: space)
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        core.zOrderRestoresInFlight = 1
        core.warpMouseToFocused(id)
        // Held, not dropped — and not warped yet.
        #expect(core.pendingMouseWarp == id)
        #expect(warped.isEmpty)
        // The last drain ends: counter drops, the held warp
        // fires for the still-focused target.
        core.zOrderRestoresInFlight = 0
        core.runPendingMouseWarp()
        #expect(warped.count == 1)
        #expect(core.pendingMouseWarp == nil)
    }

    @Test("A held warp whose focus moved on is dropped")
    func staleHeldWarpIsDropped() {
        // Slot resolution needs a real screen; a screenless
        // runner must skip, not red (the screen-guard
        // convention).
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.tiler.settings.mouse.followsFocus = true
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)",
                        frame: CGRect(
                            x: 500 * CGFloat(id - 1),
                            y: 0,
                            width: 400,
                            height: 300
                        )
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(1), in: space)
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        core.zOrderRestoresInFlight = 1
        core.warpMouseToFocused(WindowID(1))
        #expect(core.pendingMouseWarp == WindowID(1))
        // Focus moves on before the drain ends: the held warp
        // is stale and must not yank the pointer backwards.
        core.state.workspaces.focus(WindowID(2), in: space)
        core.zOrderRestoresInFlight = 0
        core.runPendingMouseWarp()
        #expect(warped.isEmpty)
        #expect(core.pendingMouseWarp == nil)
    }

    /// An overlapping drain must keep the hold: only the LAST
    /// sequence's end releases the pointer.
    @Test("An overlapping drain keeps holding the warp")
    func overlappingDrainKeepsHold() {
        // Slot resolution needs a real screen; a screenless
        // runner must skip, not red (the screen-guard
        // convention).
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.tiler.settings.mouse.followsFocus = true
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "A",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 400,
                        height: 300
                    )
                )
            )
        )
        let id = WindowID(1)
        let space = core.state.workspaces.space(of: id)!
        core.state.workspaces.focus(id, in: space)
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        core.zOrderRestoresInFlight = 2
        core.warpMouseToFocused(id)
        // The first drain ends; another still runs.
        core.zOrderRestoresInFlight = 1
        core.runPendingMouseWarp()
        #expect(warped.isEmpty)
        #expect(core.pendingMouseWarp == id)
        core.zOrderRestoresInFlight = 0
        core.runPendingMouseWarp()
        #expect(warped.count == 1)
    }

    /// The reason `runPendingMouseWarp` checks the counter
    /// ITSELF rather than leaning on `warpMouseToFocused`'s
    /// re-hold: staleness must be judged at the LAST drain's
    /// end. Judged earlier, a target that transiently lost
    /// focus to a drain's churn and regained it would be
    /// dropped mid-hold and never warp.
    @Test("Transiently lost focus regained mid-hold still warps")
    func transientFocusLossKeepsHeldWarp() {
        // Slot resolution needs a real screen; a screenless
        // runner must skip, not red (the screen-guard
        // convention).
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.tiler.settings.mouse.followsFocus = true
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)",
                        frame: CGRect(
                            x: 500 * CGFloat(id - 1),
                            y: 0,
                            width: 400,
                            height: 300
                        )
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(1), in: space)
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        core.zOrderRestoresInFlight = 2
        core.warpMouseToFocused(WindowID(1))
        #expect(core.pendingMouseWarp == WindowID(1))
        // A drain's churn transiently moves focus off the
        // target while another drain still runs...
        core.state.workspaces.focus(WindowID(2), in: space)
        core.zOrderRestoresInFlight = 1
        core.runPendingMouseWarp()
        // ...and the revert machinery puts it back before the
        // last drain ends.
        core.state.workspaces.focus(WindowID(1), in: space)
        core.zOrderRestoresInFlight = 0
        core.runPendingMouseWarp()
        #expect(warped.count == 1)
        #expect(core.pendingMouseWarp == nil)
    }

    /// Mouse-made intent is dropped at hold time, not held: a
    /// bar click's warp landing mid-drain would otherwise fire
    /// hundreds of ms after the click — a spurious pointer jump
    /// (#689 device QA). Only clickless intent (cmd-tab,
    /// keyboard nav — the case #689 was filed for) re-fires.
    @Test("A held warp near a fresh press is dropped, not held")
    func mouseMadeIntentIsDroppedAtHoldTime() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.tiler.settings.mouse.followsFocus = true
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "A",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 400,
                        height: 300
                    )
                )
            )
        )
        let id = WindowID(1)
        let space = core.state.workspaces.space(of: id)!
        core.state.workspaces.focus(id, in: space)
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        core.zOrderRestoresInFlight = 1
        // A fresh press: this intent is mouse-made (a bar
        // click), so the hold drops it.
        core.lastLeftClick = (
            Date(), CGPoint(x: 700, y: 500), nil
        )
        core.warpMouseToFocused(id)
        #expect(core.pendingMouseWarp == nil)
        core.zOrderRestoresInFlight = 0
        core.runPendingMouseWarp()
        #expect(warped.isEmpty)
        // A stale press no longer marks intent as mouse-made.
        core.zOrderRestoresInFlight = 1
        core.lastLeftClick = (
            Date().addingTimeInterval(
                -KiwiCore.selfRaiseEchoWindow - 0.1
            ),
            CGPoint(x: 700, y: 500),
            nil
        )
        core.warpMouseToFocused(id)
        #expect(core.pendingMouseWarp == id)
    }

    /// A mouse-made focus needs no warp: the pointer is where
    /// the user put it, and in a focus-driven layout the click
    /// pans the row, so warping to the settled slot yanks the
    /// pointer after it (#689 device QA). The discriminator is
    /// the #687 press stamp — a report whose window the click
    /// reached is mouse-made.
    @Test("A click-made focus report never warps")
    func clickMadeFocusReportDoesNotWarp() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.tiler.settings.mouse.followsFocus = true
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)",
                        frame: CGRect(
                            x: 500 * CGFloat(id - 1),
                            y: 0,
                            width: 400,
                            height: 300
                        )
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(1), in: space)
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        // The user clicked window 2 (press stamp resolved it);
        // its focus report must not warp — immediately or via
        // the pending slot.
        core.lastLeftClick = (
            Date(), CGPoint(x: 600, y: 100), WindowID(2)
        )
        core.handle(.windowFocused(WindowID(2)))
        #expect(warped.isEmpty)
        #expect(core.pendingMouseWarp == nil)
        // A clickless report (cmd-tab shaped) still warps.
        core.lastLeftClick = nil
        core.handle(.windowFocused(WindowID(1)))
        #expect(!warped.isEmpty)
    }
}
