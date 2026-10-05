import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A frozen clock the core's ledgers stamp and age on (#1852).
@MainActor
private final class Clock {
    var now = Date(timeIntervalSinceReferenceDate: 1_000_000)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

/// `settings` focused, `chrome` a second own window — the #1861
/// shape: Settings tiled, the replacing chrome window beside it.
@MainActor
private func makeDesk() -> (
    core: KiwiCore, clock: Clock, settings: WindowID, chrome: WindowID
) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("kiwidesk-own-front-\(UUID())")
    let core = makeTestCore(configDirectory: directory)
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    let clock = Clock()
    core.wallClock = { clock.now }
    for id in 1...2 {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: 7,
                    appName: "KiwiDesk",
                    frame: CGRect(
                        x: 100 * id,
                        y: 100,
                        width: 400,
                        height: 300
                    )
                )
            )
        )
    }
    let settings = WindowID(1)
    let space = core.state.workspaces.space(of: settings)!
    core.state.workspaces.focus(settings, in: space)
    return (core, clock, settings, WindowID(2))
}

/// An own window the GUI fronted is reported focused as intended
/// (#1861): the close-return restack stamps it as a z-order raise
/// AFTER the front, so the #431 order veto cannot help, and the
/// report used to be reverted to the window the close handed
/// focus back to.
@Suite("Own front vs. z-order echo (#1861)", .serialized)
@MainActor
struct OwnFrontEchoTests {
    @Test("A fronted own window's report survives a later stamp")
    func frontOutranksLaterStamp() {
        let (core, clock, settings, chrome) = makeDesk()
        core.noteOwnFront(number: Int(chrome.raw))
        clock.advance(0.1)
        _ = core.stampZOrderRaise([chrome], excluding: settings)
        clock.advance(0.1)
        core.handle(.windowFocused(chrome))
        #expect(core.activeSpace?.focused == chrome)
    }

    @Test("Without the front, the same report is reverted")
    func stampAloneReverts() {
        let (core, clock, settings, chrome) = makeDesk()
        _ = core.stampZOrderRaise([chrome], excluding: settings)
        clock.advance(0.1)
        core.handle(.windowFocused(chrome))
        #expect(core.activeSpace?.focused == settings)
    }

    @Test("A front older than its window no longer vetoes")
    func frontAgesOut() {
        let (core, clock, settings, chrome) = makeDesk()
        core.noteOwnFront(number: Int(chrome.raw))
        clock.advance(KiwiCore.ownFrontWindow + 0.05)
        _ = core.stampZOrderRaise([chrome], excluding: settings)
        clock.advance(0.05)
        core.handle(.windowFocused(chrome))
        #expect(core.activeSpace?.focused == settings)
    }

    @Test("A gone window's front is forgotten; no number is ignored")
    func frontIsForgottenAndValidated() {
        let (core, _, _, chrome) = makeDesk()
        core.noteOwnFront(number: Int(chrome.raw))
        #expect(core.ownFronts[chrome] != nil)
        core.forgetGoneWindow(chrome, pid: nil)
        #expect(core.ownFronts[chrome] == nil)
        core.noteOwnFront(number: 0)
        core.noteOwnFront(number: -1)
        #expect(core.ownFronts.isEmpty)
    }
}
