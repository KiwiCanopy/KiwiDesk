import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #953: the tiled Settings window's mouse resize moved
/// no neighbours. Nothing in the resize pipeline named our own
/// process — the hole was one layer below, in DELIVERY, and it
/// had two halves. The argument for both lives in
/// `.claude/rules/accessibility.md` (the AX half) and
/// `.claude/rules/input-and-animation.md` (the press half).
///
/// These are the pure pins. Neither half is observable from a
/// test process: no test raises a real tracking loop, and a
/// monitor only fires on real input, so the wiring that carries
/// each decision to the machine is guarded by scan instead
/// (`ObserverRunLoopModeSeamTests`,
/// `OwnPressMonitorSeamTests`).
@Suite("Own-process gesture delivery (#953)")
@MainActor
struct OwnWindowGestureDeliveryTests {
    @Test("Our own app also rides the event-tracking mode")
    func ownProcessObservesWhileTracking() {
        let modes = AXApplicationObserver.runLoopModes(
            pid: getpid()
        )
        #expect(modes.contains(.defaultMode))
        #expect(
            modes.contains(AXApplicationObserver.eventTracking)
        )
    }

    @Test("Every other app keeps the default mode alone")
    func otherProcessesObserveInDefaultMode() {
        // launchd (pid 1) is never KiwiDesk; nor is any pid
        // other than our own. Widening these too would let a
        // third-party AX storm re-enter our own menu and
        // slider tracking loops.
        for pid in [pid_t(1), getpid() &+ 1] {
            #expect(
                AXApplicationObserver.runLoopModes(pid: pid)
                    == [.defaultMode]
            )
        }
    }

    @Test("The modal-panel mode is bought by nobody")
    func modalPanelModeIsNeverRegistered() {
        // `.commonModes` would have carried it for free, and
        // that is the reason the two modes are named.
        for pid in [getpid(), 1, getpid() &+ 1] {
            let modes = AXApplicationObserver.runLoopModes(
                pid: pid
            )
            #expect(!modes.contains(.commonModes))
            #expect(
                !modes.contains(
                    CFRunLoopMode(
                        RunLoop.Mode.modalPanel.rawValue
                            as CFString
                    )
                )
            )
        }
    }

    @Test("Only the marked own window's press is remembered")
    func onlyTheTilingWindowsPressCounts() {
        let frame = CGRect(x: 100, y: 200, width: 800, height: 600)
        let inWindow = CGPoint(x: 5, y: 7)
        // The one own window that tiles: its press is what a
        // tiled gesture is classified from, converted into the
        // screen space the global arm's events already carry.
        #expect(
            MouseTracker.ownPressLocation(
                identifier: OwnWindowTiling.identifier,
                locationInWindow: inWindow,
                windowFrame: frame
            ) == CGPoint(x: 105, y: 207)
        )
        // Every other own window is chrome — the bars' item
        // views, the tour, Config Issues, an NSOpenPanel — and
        // a click on one must not overwrite the press the
        // gesture classifiers read (#678 item 18: per WINDOW,
        // never per process).
        for identifier in [nil, "", "kiwidesk.tour", "other"] {
            #expect(
                MouseTracker.ownPressLocation(
                    identifier: identifier,
                    locationInWindow: inWindow,
                    windowFrame: frame
                ) == nil
            )
        }
        // A windowless local event has no frame to convert
        // through, so it is nobody's press.
        #expect(
            MouseTracker.ownPressLocation(
                identifier: OwnWindowTiling.identifier,
                locationInWindow: inWindow,
                windowFrame: nil
            ) == nil
        )
    }

    @Test("Only another app's press reaches the click fan-out")
    func fanOutHearsOtherAppsAlone() {
        let tracker = MouseTracker()
        var seen: [CGPoint] = []
        tracker.onLeftMouseDown = { seen.append($0) }
        tracker.recordDown(
            at: CGPoint(x: 1, y: 2),
            from: .otherApp
        )
        #expect(seen.count == 1)
        // #446's bar-overlay exemption, and the #496/#687/#951
        // click provenance, are all built on this fan-out never
        // hearing a click on one of our own windows.
        tracker.recordDown(
            at: CGPoint(x: 3, y: 4),
            from: .ownWindow
        )
        #expect(seen.count == 1)
    }

    @Test("A release closes only the press its own arm opened")
    func releaseFollowsProvenance() {
        let tracker = MouseTracker()
        tracker.recordDown(at: .zero, from: .otherApp)
        // The own-window arm's release must not close a
        // third-party press: `press` outlives every gesture, so
        // this is how a click on chrome came to refresh a stale
        // press and hand `isResizeGesture` a location it read
        // as fresh (review, 2026-08-24).
        tracker.recordUp(from: .ownWindow)
        #expect(tracker.press?.upAt == nil)
        tracker.recordUp(from: .otherApp)
        #expect(tracker.press?.upAt != nil)
    }

    @Test("The own arm closes its own press")
    func ownReleaseClosesOwnPress() {
        let tracker = MouseTracker()
        tracker.recordDown(at: .zero, from: .ownWindow)
        tracker.recordUp(from: .otherApp)
        #expect(tracker.press?.upAt == nil)
        tracker.recordUp(from: .ownWindow)
        #expect(tracker.press?.upAt != nil)
    }

    @Test("A closed press is never reopened by a later release")
    func aClosedPressStaysClosed() {
        let tracker = MouseTracker()
        tracker.recordDown(at: .zero, from: .ownWindow)
        tracker.recordUp(from: .ownWindow)
        let closed = tracker.press?.upAt
        #expect(closed != nil)
        // The gesture is over, but `press` outlives it. Every
        // later release — a click on a bar item, the tour, a
        // panel — must leave the stamp alone: re-stamping pushes
        // this stale location back inside `isResizeGesture`'s
        // one-second window, and a Space Bar click is itself a
        // retile (review, 2026-08-24).
        tracker.recordUp(from: .ownWindow)
        #expect(tracker.press?.upAt == closed)
        tracker.recordUp(from: .otherApp)
        #expect(tracker.press?.upAt == closed)
    }
}
