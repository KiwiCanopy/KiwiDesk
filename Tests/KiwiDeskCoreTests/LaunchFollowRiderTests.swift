import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A launch's popups ride its follow (#3189): the App Rule skips a
/// popup, so it opens where the user is, and the follow left it
/// behind in the Space it launched from (Lightroom Classic's top
/// strip, a button-less panel). Through the real activation entry,
/// fold and `.windowCreated` arm, on `LaunchFollowTests`' desk;
/// each stand-down sits beside the ride it differs from by one
/// input.
@Suite("A launch's popups ride its follow (#3189)", .serialized)
@MainActor
struct LaunchFollowRiderTests {
    private typealias Desk = LaunchFollowTests
    private static let popup = WindowID(8)
    private static let main: UInt32 = 9

    /// A button-less layer-0 panel of the launched app (#2475).
    private static func popupArrives(
        on core: KiwiCore,
        id: WindowID = popup
    ) {
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 7,
                    appName: "Launched",
                    appBundleID: Desk.bundle,
                    frame: CGRect(x: 0, y: 0, width: 400, height: 40),
                    isFloating: true,
                    isTransientOverlay: true,
                    hasTitlebarButton: false
                )
            )
        )
    }

    private static func space(
        of id: WindowID,
        on core: KiwiCore
    ) -> SpaceID? {
        core.state.workspaces.space(of: id)
    }

    @Test("a popup of the launch moves with the follow")
    func ridesTheFollow() {
        let core = Desk.makeCore()
        Desk.activate(core)
        Self.popupArrives(on: core)
        // It opens where the user is: the skip is unchanged.
        #expect(Self.space(of: Self.popup, on: core) == Desk.home)
        #expect(core.state.workspaces.activeSpace == Desk.home)
        Desk.arrive(Self.main, on: core)
        #expect(core.state.workspaces.activeSpace == Desk.ruled)
        #expect(Self.space(of: Self.popup, on: core) == Desk.ruled)
        // The follow's focus is its window's, never the rider's.
        #expect(core.focusedWindowID == WindowID(Self.main))
    }

    @Test("every popup of the launch rides, not only the last")
    func everyRiderMoves() {
        let core = Desk.makeCore()
        Desk.activate(core)
        Self.popupArrives(on: core)
        Self.popupArrives(on: core, id: WindowID(6))
        Desk.arrive(Self.main, on: core)
        #expect(Self.space(of: Self.popup, on: core) == Desk.ruled)
        #expect(Self.space(of: WindowID(6), on: core) == Desk.ruled)
    }

    @Test("a popup that opened with no debt standing stays")
    func noDebtStays() {
        let core = Desk.makeCore()
        Self.popupArrives(on: core)
        Desk.activate(core)
        Desk.arrive(Self.main, on: core)
        #expect(core.state.workspaces.activeSpace == Desk.ruled)
        #expect(Self.space(of: Self.popup, on: core) == Desk.home)
    }

    @Test("a rider the user moved since stays where it was put")
    func movedByHandStays() {
        let core = Desk.makeCore()
        let other = SpaceID("3")
        core.state.workspaces.ensureSpace(other)
        Desk.activate(core)
        Self.popupArrives(on: core)
        core.fileMembership(Self.popup, into: other, from: Desk.home)
        Desk.arrive(Self.main, on: core)
        #expect(core.state.workspaces.activeSpace == Desk.ruled)
        #expect(Self.space(of: Self.popup, on: core) == other)
    }

    @Test("a full-screen rider stays: its macOS Space is its own")
    func fullScreenStays() throws {
        let core = Desk.makeCore()
        Desk.activate(core)
        Self.popupArrives(on: core)
        var rider = try #require(core.state.windows[Self.popup])
        rider.isFullscreen = true
        core.state.windows.upsert(rider)
        Desk.arrive(Self.main, on: core)
        #expect(Self.space(of: Self.popup, on: core) == Desk.home)
    }

    @Test("a popup after the follow opens in the rule's Space")
    func afterTheFollowLandsThere() {
        let core = Desk.makeCore()
        Desk.activate(core)
        Desk.arrive(Self.main, on: core)
        Self.popupArrives(on: core)
        #expect(Self.space(of: Self.popup, on: core) == Desk.ruled)
    }

    @Test("a follow that is not paid leaves its riders")
    func unpaidFollowLeavesRiders() {
        // The main window is remembered elsewhere, so nothing is
        // claimed and nothing moves.
        let core = Desk.makeCore()
        core.state.rememberedSpaces[WindowID(Self.main)] =
            .restored(Desk.ruled)
        Desk.activate(core)
        Self.popupArrives(on: core)
        Desk.arrive(Self.main, on: core)
        #expect(core.state.workspaces.activeSpace == Desk.home)
        #expect(Self.space(of: Self.popup, on: core) == Desk.home)
    }
}
