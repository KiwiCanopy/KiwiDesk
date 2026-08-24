import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #953: the tiled Settings window's mouse resize moved
/// no neighbours. Nothing in the resize pipeline named our own
/// process — the hole was one layer below, in DELIVERY.
///
/// AX notifications for every observed app arrive on OUR run
/// loop. A source registered only in `.defaultMode` is deaf
/// while that run loop runs a tracking loop, and our own
/// window's live resize IS a tracking loop in this process: the
/// gesture the drag pipeline had to see was exactly the window
/// during which it could not see anything.
@Suite("Own-process AX delivery during our own tracking loops")
@MainActor
struct OwnWindowGestureDeliveryTests {
    @Test("Our own app's notifications ride the common modes")
    func ownProcessObservesInCommonModes() {
        #expect(
            AXApplicationObserver.runLoopMode(pid: getpid())
                == .commonModes
        )
    }

    @Test("Every other app keeps the default mode alone")
    func otherProcessesObserveInDefaultMode() {
        // launchd (pid 1) is never KiwiDesk; nor is any pid
        // other than our own. Widening these too would let a
        // third-party AX storm re-enter our own menu and
        // slider tracking loops.
        #expect(
            AXApplicationObserver.runLoopMode(pid: 1)
                == .defaultMode
        )
        #expect(
            AXApplicationObserver.runLoopMode(
                pid: getpid() &+ 1
            ) == .defaultMode
        )
    }
}
