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
}
