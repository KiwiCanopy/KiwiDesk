import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A follow-shaped switch lifts the landing Space's float layer
/// above its tiled plane, as `focusSpace` does (#412) — decided
/// in `followSwitch` for every caller, not per call site (#1727).
///
/// The raise is observed through the echo ledger its stamp
/// writes (`zOrderRaiseEchoes`), synchronously at the raise. The
/// float's element is the test process's own application, which
/// raises on the main actor, so the sequence completes inline
/// and touches no other process.
@Suite("A follow switch raises the float layer (#1727)", .serialized)
@MainActor
struct FollowSwitchFloatRaiseTests {
    private static let pid = ProcessInfo.processInfo.processIdentifier
    private static let bundle = "com.example.app"

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwidesk-\(UUID().uuidString)")
        )
    }

    private func window(
        _ id: UInt32,
        floating: Bool = false,
        sticky: StickyScope = .none
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: Self.pid,
            appName: "App",
            appBundleID: Self.bundle,
            title: "Title",
            frame: CGRect(x: 100, y: 100, width: 400, height: 300),
            isFloating: floating,
            stickyScope: sticky
        )
    }

    /// Space 1 (active) holds tiled window 1; Space 2 holds tiled
    /// window 2 and float 3, the one float with an element.
    private func seed(_ core: KiwiCore) {
        for space in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        let members: [(UInt32, String, Bool)] = [
            (1, "1", false), (2, "2", false), (3, "2", true),
        ]
        for (id, space, floating) in members {
            core.state.windows.upsert(window(id, floating: floating))
            core.state.workspaces.add(WindowID(id), to: SpaceID(space))
        }
        // Space 2's focus first, so `lastFocused` is window 1.
        core.state.workspaces.focus(WindowID(2), in: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.eventLoop.elements[Self.pid] = [
            WindowID(3): AXUIElementCreateApplication(Self.pid)
        ]
        #expect(core.zOrderRaiseEchoes[WindowID(3)] == nil)
    }

    private func expectRaised(_ core: KiwiCore) {
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(core.zOrderRaiseEchoes[WindowID(3)] != nil)
    }

    @Test("move_to_space_and_follow raises the landing floats")
    func moveFollowRaises() {
        let core = makeCore()
        seed(core)
        #expect(
            core.execute("move_to_space_and_follow", args: [.string("2")])
                .isSuccess
        )
        expectRaised(core)
    }

    @Test("The launch cycle raises the landing floats")
    func launchCycleRaises() {
        let core = makeCore()
        seed(core)
        // The cycle asks the OS frontmost; left nil elsewhere, it
        // keeps the #292 preflight inert for the move verb.
        core.frontmostPIDProvider = { Self.pid }
        #expect(core.cycleToNextWindow(bundleID: Self.bundle))
        expectRaised(core)
    }

    @Test("The launch follow raises the landing floats")
    func launchFollowRaises() {
        let core = makeCore()
        seed(core)
        #expect(core.payLaunchFollow(WindowID(2), into: "2"))
        expectRaised(core)
    }

    @Test("A Space Bar glyph click raises the landing floats")
    func spaceBarClickRaises() {
        let core = makeCore()
        seed(core)
        core.focusFromSpaceBar(WindowID(2), on: "2")
        expectRaised(core)
    }

    /// The closing hand-back asks the focus anchor: a floating
    /// sticky traveler homed on Space 2 and drawn on Space 1 is
    /// never Space 1's slot, yet it is the focus to hand back.
    @Test("The raise hands focus back to a sticky traveler")
    func travelerGetsFocusBack() {
        let core = makeCore()
        seed(core)
        core.state.windows.upsert(
            window(50, floating: true, sticky: .global)
        )
        core.state.workspaces.add(WindowID(50), to: "2")
        core.state.workspaces.focus(WindowID(50), in: "2")
        core.state.windows.upsert(window(4, floating: true))
        core.state.workspaces.add(WindowID(4), to: "1")
        core.eventLoop.elements[Self.pid]?[WindowID(4)] =
            AXUIElementCreateApplication(Self.pid)
        #expect(core.activeSpace?.focused == WindowID(1))
        core.eventLoop.lastCommandedFocus = nil
        core.raiseFloatsAndSticky(thenFocus: WindowID(50))
        #expect(core.zOrderRaiseEchoes[WindowID(4)] != nil)
        #expect(core.eventLoop.lastCommandedFocus != nil)
    }
}
