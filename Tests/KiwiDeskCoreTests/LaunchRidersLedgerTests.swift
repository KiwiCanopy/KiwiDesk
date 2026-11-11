import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The riders of a launch debt (#3189): noted only while their
/// app's debt stands, handed out once by its claim, and gone with
/// the debt, since they are one value. Plus the fold's one input.
@Suite("Launch riders live and end with the debt (#3189)")
@MainActor
struct LaunchRidersLedgerTests {
    private typealias Rider = LaunchFollowIntent.Rider
    private static let app = "app.launched"
    private static let rider = Rider(
        window: WindowID(8),
        from: SpaceID("1")
    )
    private static let now = Date(timeIntervalSince1970: 1_000)

    /// A debt owed to `app` with one rider noted.
    private static func owing() -> LaunchFollowIntent {
        let ledger = LaunchFollowIntent()
        ledger.record(app, at: now)
        ledger.noteRider(rider, of: app, at: now)
        return ledger
    }

    @Test("the claim hands the riders out, once")
    func claimedOnce() {
        let ledger = Self.owing()
        #expect(ledger.claim(Self.app, at: Self.now) == [Self.rider])
        #expect(ledger.claim(Self.app, at: Self.now) == nil)
        // Owed again, the app starts with none.
        ledger.record(Self.app, at: Self.now)
        #expect(ledger.claim(Self.app, at: Self.now) == [])
    }

    @Test("a window noted twice rides once, with its last Space")
    func notedOnce() {
        let ledger = Self.owing()
        let moved = Rider(window: Self.rider.window, from: SpaceID("3"))
        ledger.noteRider(moved, of: Self.app, at: Self.now)
        #expect(ledger.claim(Self.app, at: Self.now) == [moved])
    }

    @Test("no debt, or another app's, notes nothing")
    func unowedNotesNothing() {
        let ledger = LaunchFollowIntent()
        ledger.noteRider(Self.rider, of: Self.app, at: Self.now)
        ledger.record(Self.app, at: Self.now)
        #expect(ledger.claim(Self.app, at: Self.now) == [])
        ledger.record("app.other", at: Self.now)
        ledger.noteRider(Self.rider, of: Self.app, at: Self.now)
        #expect(ledger.claim("app.other", at: Self.now) == [])
    }

    /// Open or Focus owes at the command and the app's activation
    /// owes again: one open, so a popup between the two still rides.
    @Test("the same app owed again keeps its riders")
    func sameAppKeepsRiders() {
        let ledger = Self.owing()
        ledger.record(Self.app, at: Self.now)
        #expect(ledger.claim(Self.app, at: Self.now) == [Self.rider])
    }

    @Test("an ended debt takes its riders with it")
    func endersRetire() {
        let late = Self.now.addingTimeInterval(
            LaunchFollowIntent.drainWindow
        )
        let enders: [(String, (LaunchFollowIntent) -> Void)] = [
            ("another app's debt", { $0.record("app.other", at: Self.now) }),
            ("expiry", { _ = $0.owed(at: late) }),
            ("a refused open", { $0.forget(pending: Self.app) }),
            ("another activation", { $0.forget(keeping: "app.other") }),
            ("a Desktop switch", { $0.forget() }),
        ]
        for (name, end) in enders {
            let ledger = Self.owing()
            end(ledger)
            // Owed afresh, nothing of the ended debt is left.
            ledger.record(Self.app, at: late)
            #expect(
                ledger.claim(Self.app, at: late) == [],
                "\(name) left riders"
            )
        }
    }

    // MARK: The fold's input

    private static let shown = SpaceID("1")
    private static let ruled = SpaceID("2")

    private static func state() -> StateCoordinator {
        var state = StateCoordinator()
        state.workspaces.ensureSpace(shown)
        state.workspaces.ensureSpace(ruled)
        state.appRules[app] = ruled
        return state
    }

    private static func window(
        _ id: UInt32,
        popup: Bool
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 7,
            appName: "Launched",
            appBundleID: app,
            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
            isFloating: popup,
            isTransientOverlay: popup,
            hasTitlebarButton: popup ? false : true
        )
    }

    @Test("the fold names the rule a popup skipped")
    func foldNamesTheSkippedRule() {
        var state = Self.state()
        let effects = state.apply(
            .windowCreated(Self.window(2, popup: true))
        )
        #expect(effects.popupSkippedRule == Self.ruled)
        #expect(effects.placedByAppRule == nil)
        #expect(state.workspaces.space(of: WindowID(2)) == Self.shown)
    }

    @Test("a ruled window, an active rule and a held popup name none")
    func foldNamesNoneElsewhere() {
        var state = Self.state()
        let ruledWindow = state.apply(
            .windowCreated(Self.window(3, popup: false))
        )
        #expect(ruledWindow.popupSkippedRule == nil)

        var here = Self.state()
        here.appRules[Self.app] = Self.shown
        let active = here.apply(
            .windowCreated(Self.window(4, popup: true))
        )
        #expect(active.popupSkippedRule == nil)

        var held = Self.state()
        held.rememberedSpaces[WindowID(5)] = .restored(Self.shown)
        let remembered = held.apply(
            .windowCreated(Self.window(5, popup: true))
        )
        #expect(remembered.popupSkippedRule == nil)
    }

    /// The follow's own stand-downs: a lens's quiet open (#3122)
    /// and a Pocket key's window, claimed or awaited (#2612).
    @Test("a quiet popup and a Pocket key's popup name none")
    func foldNamesNoneForQuietOrPocket() {
        var quiet = Self.state()
        quiet.arrivalFocus = .quiet(into: nil)
        #expect(
            quiet.apply(.windowCreated(Self.window(6, popup: true)))
                .popupSkippedRule == nil
        )
        var claimed = Self.state()
        claimed.pocketClaimed = .claimed(WindowID(6))
        #expect(
            claimed.apply(.windowCreated(Self.window(6, popup: true)))
                .popupSkippedRule == nil
        )
        var awaited = Self.state()
        awaited.pocketClaimed = .awaited(WindowID(6))
        #expect(
            awaited.apply(.windowCreated(Self.window(6, popup: true)))
                .popupSkippedRule == nil
        )
    }
}
