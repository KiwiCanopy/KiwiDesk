import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #177: Settings is a tracked float; KiwiDesk's panels,
/// overlays, and border windows remain fully ignored. Accessory
/// apps are observed before their first real window appears.
@Suite("Own-window and accessory-app classification (#177)")
struct SelfWindowExclusionTests {
    @Test("The current process is recognized as self")
    func ownProcessIsSelf() {
        #expect(EventLoop.isOwnProcess(getpid()))
    }

    @Test("Other processes are not self")
    func otherProcessesNotSelf() {
        // launchd (pid 1) is never KiwiDesk; nor is any pid
        // other than our own.
        #expect(!EventLoop.isOwnProcess(1))
        #expect(!EventLoop.isOwnProcess(getpid() &+ 1))
    }

    @Test(
        "Own main windows and key-capable titled dialogs are managed; "
            + "own panels stay ignored"
    )
    func ownWindowClassification() {
        #expect(
            !EventLoop.shouldIgnoreOwnWindow(
                pid: getpid(),
                canBecomeMain: true
            )
        )
        #expect(
            EventLoop.shouldIgnoreOwnWindow(
                pid: getpid(),
                canBecomeMain: false
            )
        )
        // Key-capable titled dialogs/alerts (e.g. Sparkle update alerts)
        // are tracked so focus rings and floating chrome stay in sync.
        #expect(
            !EventLoop.shouldIgnoreOwnWindow(
                pid: getpid(),
                canBecomeMain: false,
                canBecomeKey: true,
                isTitled: true,
                isVisible: true
            )
        )
        // Borderless utility panels (e.g. ⌃⌥K shortcuts) stay ignored.
        #expect(
            EventLoop.shouldIgnoreOwnWindow(
                pid: getpid(),
                canBecomeMain: false,
                canBecomeKey: true,
                isTitled: false,
                isVisible: true
            )
        )
        // Hidden/ordered-out windows stay ignored.
        #expect(
            EventLoop.shouldIgnoreOwnWindow(
                pid: getpid(),
                canBecomeMain: true,
                isVisible: false
            )
        )
    }

    @Test("Windowless accessory apps attach before a window appears")
    func accessoryAttachment() {
        #expect(
            EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .regular,
                isIgnored: false
            )
        )
        #expect(
            EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .accessory,
                isIgnored: false
            )
        )
        #expect(
            !EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .prohibited,
                isIgnored: false
            )
        )
        #expect(
            EventLoop.shouldAttach(
                pid: getpid(),
                activationPolicy: .prohibited,
                isIgnored: false
            )
        )
        #expect(
            !EventLoop.shouldAttach(
                pid: 1,
                activationPolicy: .regular,
                isIgnored: true
            )
        )
    }

    @Test("Prohibited transitions and queued callbacks lose ownership")
    func callbackOwnershipTransition() {
        #expect(
            EventLoop.ownsObservation(
                hasObserver: true,
                pid: 1,
                activationPolicy: .regular,
                isIgnored: false
            )
        )
        #expect(
            !EventLoop.ownsObservation(
                hasObserver: true,
                pid: 1,
                activationPolicy: .prohibited,
                isIgnored: false
            )
        )
        #expect(
            !EventLoop.ownsObservation(
                hasObserver: false,
                pid: 1,
                activationPolicy: .regular,
                isIgnored: false
            )
        )
    }

    @Test("Own window is never a transient overlay (#315)")
    func ownWindowKeepsRing() {
        // No own window classifies as a launcher-style overlay —
        // that classification suppresses the focus ring. The
        // Settings window tiles outright (#678 item 18); the
        // force-floated own chrome (tour, Config Issues) keeps
        // its ring. Any own window that reaches tracking is
        // main-capable by construction.
        #expect(
            !EventLoop.classifiesAsOverlay(
                pid: getpid(),
                activationPolicy: .accessory
            )
        )
        #expect(
            !EventLoop.classifiesAsOverlay(
                pid: getpid(),
                activationPolicy: .regular
            )
        )
        // Third-party accessory apps stay swept (#300); regular
        // apps never classify structurally.
        #expect(
            EventLoop.classifiesAsOverlay(
                pid: 1,
                activationPolicy: .accessory
            )
        )
        #expect(
            !EventLoop.classifiesAsOverlay(
                pid: 1,
                activationPolicy: .regular
            )
        )
    }

    @Test("Accessory and unmarked own windows force floating")
    func forceFloatPolicy() {
        #expect(
            EventLoop.shouldForceFloat(
                pid: 1,
                activationPolicy: .accessory,
                tilesAsOwnWindow: false
            )
        )
        // Own chrome — the tour, the Config Issues window —
        // carries no tiling mark and stays force-floated.
        #expect(
            EventLoop.shouldForceFloat(
                pid: getpid(),
                activationPolicy: .regular,
                tilesAsOwnWindow: false
            )
        )
        #expect(
            !EventLoop.shouldForceFloat(
                pid: 1,
                activationPolicy: .regular,
                tilesAsOwnWindow: false
            )
        )
    }

    /// The live verdict, through the seam the mark is read by.
    /// The static above proves the RULE; this proves the read —
    /// hardcode `tilesAsOwnWindow: false` at the call site, or
    /// compare a different constant, and only this reds
    /// (`tests.md`: a behavior change owes a test that fails
    /// when it is reverted).
    @MainActor
    @Test("The float verdict reads the mark through the seam")
    func forceFloatConsultsTheMark() {
        let loop = EventLoop()
        let id = WindowID(4242)
        loop.ownWindowIdentifier = { _ in OwnWindowTiling.identifier }
        #expect(!loop.shouldForceFloat(pid: getpid(), id: id))
        // Own chrome: a window with no mark, and one carrying
        // somebody else's — both stay force-floated.
        loop.ownWindowIdentifier = { _ in nil }
        #expect(loop.shouldForceFloat(pid: getpid(), id: id))
        loop.ownWindowIdentifier = { _ in "kiwidesk.some.other" }
        #expect(loop.shouldForceFloat(pid: getpid(), id: id))
    }

    @Test("The marked own window tiles; the mark exempts nobody else")
    func ownWindowTilingMark() {
        // The Settings window (#678 item 18): own process, marked
        // by `OwnWindowTiling.identifier` — tiles like any other
        // window.
        #expect(
            !EventLoop.shouldForceFloat(
                pid: getpid(),
                activationPolicy: .accessory,
                tilesAsOwnWindow: true
            )
        )
        // The mark discriminates OWN windows only: a third-party
        // accessory window stays swept whatever the flag claims.
        #expect(
            EventLoop.shouldForceFloat(
                pid: 1,
                activationPolicy: .accessory,
                tilesAsOwnWindow: true
            )
        )
    }
}
