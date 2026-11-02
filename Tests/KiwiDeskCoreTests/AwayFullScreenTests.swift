import Foundation
import Testing

@testable import KiwiDeskCore

/// A window left on its native full-screen Space stays known
/// (#2930): the away census reads user Desktops alone, so a census
/// absence is no close while the compositor still hosts the window
/// on one of the census's full-screen Spaces, and its KiwiHub row
/// reads Full Screen and refuses Swap here and Move here.
/// Process-global overrides, so serialized.
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

    /// No user Desktop hosts the window; Space 9 is full screen.
    private let emptyCensus = DesktopCensus(
        hosts: [:],
        shown: [1],
        fullScreen: [9]
    )

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
        // Open or Focus finds it listed, so it activates, never
        // opens a fresh window.
        #expect(core.awayReach(bundleID: "com.apple.finder")?.listsAny == true)
    }

    @Test("a user Desktop, an unlisted Space or no Space still prunes")
    func otherReadingsPrune() {
        defer { resetAuthorityOverrides() }
        let readings: [WindowSpaceReading] = [
            .hosted(4), .hosted(99), .gone, .unavailable,
        ]
        for reading in readings {
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
        DesktopVerbBridge.reset()
        WMBridge.classResolverOverride = { desktopVerbBridgeClasses[$0] }
        defer {
            WMBridge.classResolverOverride = nil
            resetAuthorityOverrides()
        }
        let core = makeCore()
        core.state.awayWindows[WindowID(7)]?.nativeSpace = 9
        let row = core.jumpEntries().first
        #expect(row?.status == .fullscreen)
        #expect(row?.swapBlock == .fullScreen)
        #expect(row?.moveBlock == .fullScreen)
        #expect(row?.movesHere == false)
        #expect(core.swapRefusal(.window(WindowID(7))) == .fullScreen)
        #expect(core.moveHereRefusal(.window(WindowID(7))) == .fullScreen)
        #expect(core.moveHere(.window(WindowID(7))) == false)
        // On a user Desktop it is the other-Desktop row it was.
        core.state.awayWindows[WindowID(7)]?.nativeSpace = 4
        let desk = core.jumpEntries().first
        #expect(desk?.status == .away(desktop: 2))
        #expect(desk?.swapBlock == .otherDesktop(2))
        #expect(desk?.moveBlock == nil)
        #expect(desk?.movesHere == true)
        #expect(core.moveHereRefusal(.window(WindowID(7))) == nil)
    }

    /// The owner's eyeball: from your full-screen window, a row on
    /// Desktop 1 said "Desktop 1"; yours is the reason.
    @Test("your full-screen window refuses every row's swap first")
    func yoursFullScreenRefusesFirst() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        var mine = ManagedWindow(
            id: WindowID(5),
            pid: 200,
            appName: "Claude",
            appBundleID: "com.anthropic.claudefordesktop"
        )
        mine.isFullscreen = true
        core.eventLoop.onEvent(.windowCreated(mine))
        _ = core.focusWindow(WindowID(5), warp: false)
        #expect(core.jumpSwapPartner(in: "1") == WindowID(5))
        let away = core.jumpEntries().first {
            $0.target == .window(WindowID(7))
        }
        #expect(away?.swapBlock == .yoursFullScreen)
        #expect(core.swapRefusal(.window(WindowID(7))) == .yoursFullScreen)
        // Not yours: the row's own place again.
        core.state.windows.setFullscreen(WindowID(5), false)
        #expect(core.swapRefusal(.window(WindowID(7))) == .otherDesktop(2))
    }
}
