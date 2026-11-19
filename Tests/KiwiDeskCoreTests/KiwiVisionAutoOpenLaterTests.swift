import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Later arrivals of a lens's quiet open (#3497 ▸ Ruling): with no
/// member open, every opened app owes `open_in_background`'s hold,
/// so an app that brings itself forward after the first window took
/// the owed move hands the focus back; the app whose window took it
/// is lifted, so its own reports keep the move.
@Suite("A lens's later arrivals take no focus (#3497)", .serialized)
@MainActor
struct KiwiVisionAutoOpenLaterTests {
    typealias F = KiwiVisionAutoOpenTests
    typealias Focus = KiwiVisionAutoOpenFocusTests

    static func activate(_ app: String, pid: Int32, on core: KiwiCore) {
        core.noteAppActivation(
            AppActivation(pid: pid, bundleID: app, launchedAt: nil),
            now: core.wallClock()
        )
    }

    /// The lens on with no member open, `music`'s window arrived
    /// and holding the owed focus.
    static func firstArrived() -> KiwiCore {
        let core = Focus.owing()
        Focus.arrive(7, bundleID: F.music, on: core)
        #expect(core.focusedWindowID == WindowID(7))
        return core
    }

    @Test("every app opened with none open owes the hand-back")
    func everyAppIsHeld() {
        let core = Focus.owing()
        #expect(core.launchFollow.holds.opened[F.music] != nil)
        #expect(core.launchFollow.holds.opened[F.notes] != nil)
    }

    @Test("a second app activating itself hands the focus back")
    func secondActivationHandedBack() {
        let core = Self.firstArrived()
        var log: [String] = []
        core.onLog = { log.append($0) }
        Self.activate(F.notes, pid: 900_180, on: core)
        #expect(core.launchFollow.holds.handedBack[F.notes] != nil)
        #expect(log.contains { $0.hasSuffix("handed back to w7") })
    }

    @Test("a second app's window taking the focus is handed back")
    func secondFocusHandedBack() {
        let core = Self.firstArrived()
        Focus.arrive(8, bundleID: F.notes, on: core)
        #expect(core.focusedWindowID == WindowID(7))
        core.handle(.windowFocused(WindowID(8)))
        #expect(core.focusedWindowID == WindowID(7))
    }

    /// Without the lift, the first app's unclaimed hold would hand
    /// back the user's own switch to it inside the grace.
    @Test("the app that took the owed move is lifted")
    func firstAppIsLifted() {
        let core = Self.firstArrived()
        #expect(core.launchFollow.holds.opened[F.music] == nil)
        core.focusWindow(WindowID(1), warp: false)
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
    }

    /// The accepted flicker: the first app's early activation is
    /// handed back, then its window takes the move, and the echo
    /// of that hand-back does not undo it.
    @Test("an early activation's echo does not undo the owed move")
    func earlyActivationEchoCleared() {
        let core = Focus.owing()
        var log: [String] = []
        core.onLog = { log.append($0) }
        Self.activate(F.music, pid: 900_181, on: core)
        #expect(log.contains { $0.hasSuffix("handed back to w1") })
        #expect(core.launchFollow.holds.handedBack[F.music] != nil)
        Focus.arrive(7, bundleID: F.music, on: core)
        #expect(core.focusedWindowID == WindowID(7))
        #expect(
            !core.launchFollow.holds.echoes(F.music, at: core.wallClock())
        )
        core.focusWindow(WindowID(1), warp: false)
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
    }

    @Test("a cancelled move keeps every hold")
    func cancelKeepsHolds() {
        let core = Focus.owing()
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(0.1),
            point: .zero,
            reached: nil
        )
        Focus.arrive(7, bundleID: F.music, on: core)
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.launchFollow.holds.opened[F.music] != nil)
        #expect(core.launchFollow.holds.opened[F.notes] != nil)
    }
}
