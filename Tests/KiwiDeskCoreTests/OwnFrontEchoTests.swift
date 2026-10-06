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
/// shape — and w3, another app's window.
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
    let own = pid_t(ProcessInfo.processInfo.processIdentifier)
    for id in 1...3 {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: id == 3 ? 7 : own,
                    appName: id == 3 ? "Other" : "KiwiDesk",
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

    /// The user going to another app ends the front: a later
    /// raise's echo of the fronted window is reverted again.
    @Test("Focus honored in another app retires the front")
    func otherAppRetiresFront() {
        let (core, clock, _, chrome) = makeDesk()
        let other = WindowID(3)
        core.noteOwnFront(number: Int(chrome.raw))
        clock.advance(0.1)
        core.handle(.windowFocused(other))
        #expect(core.activeSpace?.focused == other)
        clock.advance(0.1)
        _ = core.stampZOrderRaise([chrome], excluding: other)
        clock.advance(0.1)
        core.handle(.windowFocused(chrome))
        #expect(core.activeSpace?.focused == other)
    }

    /// A shuffle among our own windows keeps it: the window a
    /// close hands focus back to may report in between.
    @Test("Focus honored on another own window keeps the front")
    func ownShuffleKeepsFront() {
        let (core, clock, settings, chrome) = makeDesk()
        core.noteOwnFront(number: Int(chrome.raw))
        clock.advance(0.05)
        core.handle(.windowFocused(settings))
        clock.advance(0.05)
        _ = core.stampZOrderRaise([chrome], excluding: settings)
        clock.advance(0.1)
        core.handle(.windowFocused(chrome))
        #expect(core.activeSpace?.focused == chrome)
    }

    @Test("A native tab switch carries the front to the new id")
    func frontFollowsRekey() {
        let (core, _, _, chrome) = makeDesk()
        core.noteOwnFront(number: Int(chrome.raw))
        let tab = WindowID(40)
        core.handleWindowRekeyed(old: chrome, new: tab)
        #expect(core.ownFronts[chrome] == nil)
        #expect(core.ownFronts[tab] != nil)
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
