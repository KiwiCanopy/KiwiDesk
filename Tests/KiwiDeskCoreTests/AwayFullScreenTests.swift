import Foundation
import Testing

@testable import KiwiDeskCore

/// A window left on its native full-screen Space stays known
/// (#2930): the away census reads user Desktops alone, so a census
/// absence is no close while the compositor still hosts the window
/// on a full-screen Space, and its KiwiHub row refuses Swap here
/// and Move here as full screen. Process-global overrides, so
/// serialized.
@MainActor
@Suite("An away window on a full-screen Space", .serialized)
struct AwayFullScreenTests {
    /// Desktop 1 shown, Desktop 4 away, Space 9 a full-screen one.
    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(4, display: "UUID-A"),
            authoritySpace(9, display: "UUID-A", isUser: false),
        ]
        let core = makeAuthorityCore()
        core.desktopMemory.readWindowSpace = { _ in .hosted(4) }
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        let window = ManagedWindow(
            id: WindowID(7),
            pid: 100,
            appName: "Finder",
            appBundleID: "com.apple.finder"
        )
        core.eventLoop.onEvent(.windowCreated(window))
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(7), wasMinimized: false)
        )
        return core
    }

    private let emptyCensus = DesktopCensus(hosts: [:], shown: [1])

    private func destroyed(_ core: KiwiCore) -> () -> Int {
        var count = 0
        core.bus.addSink { event, _ in
            if event == .windowDestroyed { count += 1 }
        }
        return { count }
    }

    @Test("a census absence is no close on a full-screen Space")
    func fullScreenHostIsKept() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        #expect(core.state.awayWindows[WindowID(7)] != nil)
        let count = destroyed(core)
        core.desktopMemory.readWindowSpace = { _ in .hosted(9) }
        core.desktopMemory.readCensus = { _ in self.emptyCensus }
        core.refreshAwayWindows()
        #expect(core.state.awayWindows[WindowID(7)]?.nativeSpace == 9)
        #expect(count() == 0)
    }

    @Test("a user Desktop host or no Space at all still prunes")
    func otherReadingsPrune() {
        defer { resetAuthorityOverrides() }
        for reading in [WindowSpaceReading.hosted(4), .gone, .unavailable] {
            let core = makeCore()
            let count = destroyed(core)
            core.desktopMemory.readWindowSpace = { _ in reading }
            core.desktopMemory.readCensus = { _ in self.emptyCensus }
            core.refreshAwayWindows()
            #expect(core.state.awayWindows[WindowID(7)] == nil, "\(reading)")
            #expect(count() == 1, "\(reading)")
        }
    }

    @Test("its row and its press refuse both picks as full screen")
    func rowRefusesAsFullScreen() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.awayWindows[WindowID(7)]?.nativeSpace = 9
        let row = core.jumpEntries().first
        #expect(row?.swapBlock == .fullScreen)
        #expect(row?.moveBlock == .fullScreen)
        #expect(row?.movesHere == false)
        #expect(core.swapRefusal(.window(WindowID(7))) == .fullScreen)
        #expect(core.moveHereRefusal(.window(WindowID(7))) == .fullScreen)
        // On a user Desktop it is the other-Desktop row it was.
        core.state.awayWindows[WindowID(7)]?.nativeSpace = 4
        let desk = core.jumpEntries().first
        #expect(desk?.swapBlock != .fullScreen)
        #expect(desk?.moveBlock == nil)
        #expect(core.moveHereRefusal(.window(WindowID(7))) == nil)
    }
}
