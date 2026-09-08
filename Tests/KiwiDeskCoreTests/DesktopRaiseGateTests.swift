import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop raise gate (#1345): raising a window the
/// compositor is not drawing makes macOS switch to it, so
/// `focusWindow` refuses the verb whole and `raiseWindow` refuses
/// the deferred raise. The read is the compositor's on-screen flag
/// — never state, which still held the departed window on the
/// device, its app's destroy seconds behind the swipe.
@Suite("Desktop raise gate (#1345)")
@MainActor
struct DesktopRaiseGateTests {
    private static let refusalNeedle = "refused"

    /// Two windows, 2 focused; 1 is the raise target.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-raise-gate-\(UUID().uuidString)"
                )
        )
        for raw: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: pid_t(raw),
                        appName: "App\(raw)"
                    )
                )
            )
        }
        core.state.workspaces.focus(WindowID(2), in: SpaceID(1))
        return core
    }

    @Test("Not on screen crosses Desktops")
    func offScreenCrosses() {
        let core = makeCore()
        core.windowIsOnScreen = { _ in false }
        #expect(core.raiseCrossesDesktops(WindowID(1)))
    }

    /// Drawn, or unknown to the server (a close in flight, or no
    /// read at all): the raise is harmless or wanted.
    @Test("On screen or unknown never crosses")
    func onScreenAndUnknownDoNotCross() {
        let core = makeCore()
        for reading in [true, nil] as [Bool?] {
            core.windowIsOnScreen = { _ in reading }
            #expect(
                !core.raiseCrossesDesktops(WindowID(1)),
                "\(String(describing: reading))"
            )
        }
    }

    /// The verb is refused WHOLE: state focus, the displacement
    /// note and the pointer stay where they were, and the log
    /// says so.
    @Test("focusWindow refuses the verb, ahead of the state write")
    func focusWindowRefusesWhole() {
        let core = makeCore()
        core.windowIsOnScreen = { $0 == WindowID(1) ? false : true }
        core.tiler.placements = PlacementLedger()
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.focusWindow(WindowID(1), warp: true)
        #expect(core.activeSpace?.focused == WindowID(2))
        #expect(core.tiler.placements.recent(WindowID(2), at: Date()) == nil)
        #expect(core.pendingMouseWarp == nil)
        #expect(log.contains { $0.contains(Self.refusalNeedle) })
    }

    @Test("focusWindow takes an on-screen window without a word")
    func focusWindowFocusesShown() {
        let core = makeCore()
        core.windowIsOnScreen = { _ in true }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.focusWindow(WindowID(1), warp: false)
        #expect(core.activeSpace?.focused == WindowID(1))
        #expect(!log.contains { $0.contains(Self.refusalNeedle) })
    }

    /// The deferred path re-asks at fire time: a pending raise
    /// whose target left in the meantime is refused there.
    @Test("raiseWindow refuses the deferred raise too")
    func raiseWindowRefuses() {
        let core = makeCore()
        core.windowIsOnScreen = { _ in false }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.raiseWindow(WindowID(2))
        #expect(log.contains { $0.contains(Self.refusalNeedle) })
    }
}
