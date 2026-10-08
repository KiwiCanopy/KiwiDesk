import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// One case per #2002 clause the other suites leave inert: each
/// reds when its clause ALONE is removed from
/// `KiwiCore+DelayedCloseReturn` or the distrust machine's
/// opening record.
@Suite("Delayed close return: clauses (#2002)", .serialized)
@MainActor
struct DelayedCloseClauseTests {
    let fx = DelayedCloseFixture()

    /// A lazy app reports the same focus twice (#887); the
    /// duplicate is not the user moving on.
    @Test("The successor's duplicate report keeps the debt")
    func duplicateReportKeepsTheDebt() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        core.handle(.windowFocused(fx.successor))
        core.deferred.cancel(.focusFollow)
        #expect(core.delayedCloseDebt?.followed == true)
        fx.confirmClose(core)
        fx.expectReturned(core, log)
    }

    /// A census-blind arm refusal records its arm as the cause.
    @Test("A blind arm opening records its cause and notes no debt")
    func blindOpeningRecordsItsCause() {
        let (core, _) = fx.makeCore()
        defer { fx.tearDown() }
        core.eventLoop.refuseRemoval(
            fx.closing,
            pid: fx.app,
            app: AppRef(bundleID: "com.example.app", name: "App"),
            blind: .fullscreen
        )
        let cause = core.eventLoop.removalDistrusted[fx.closing]?.cause
        #expect(cause == .fullscreen)
        fx.keySuccessor(core)
        #expect(core.delayedCloseDebt == nil)
    }

    @Test("Another app's window keyed elsewhere notes no debt")
    func otherAppNotesNothing() {
        let (core, _) = fx.makeCore()
        defer { fx.tearDown() }
        let bystander = fx.addBystander(core)
        fx.refuse(core)
        core.handle(.windowFocused(bystander))
        core.deferred.cancel(.focusFollow)
        #expect(core.delayedCloseDebt == nil)
    }

    /// The successor carried into the closed window's Space and
    /// focused there: the return would raise over it on one Space.
    @Test("The active Space being the owed one stands down")
    func activeOwedSpaceStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        core.state.workspaces.add(fx.successor, to: "1")
        core.state.workspaces.activate("1")
        core.state.workspaces.focus(fx.successor, in: "1")
        fx.confirmClose(core)
        #expect(!log.has("close-return: raising"))
        #expect(log.has("return stood down (focus moved on)"))
    }

    @Test("Another window focused on the successor's Space stands down")
    func otherFocusStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        let bystander = fx.addBystander(core)
        fx.refuse(core)
        fx.keySuccessor(core)
        core.state.workspaces.focus(bystander, in: "2")
        fx.confirmClose(core)
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(!log.has("close-return: raising"))
        #expect(log.has("return stood down (focus moved on)"))
    }

    @Test("A minimize confirmed late is no close and heals nothing")
    func minimizeHealsNothing() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        fx.confirmClose(core, minimized: true)
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(!log.has("confirmed late"))
        #expect(core.delayedCloseDebt == nil)
    }

    @Test("A window re-filed before the confirmation heals nothing")
    func refiledWindowHealsNothing() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        core.state.workspaces.add(fx.closing, to: "3")
        fx.confirmClose(core)
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(!log.has("confirmed late"))
        #expect(!log.has("close-return: raising"))
    }
}
