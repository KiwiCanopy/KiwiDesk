import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The riders' ledger (#3189): noted only while their app's debt
/// stands, taken once at its payment, and retired wherever the
/// debt is. Plus the fold's one input to it.
@Suite("Launch riders live and end with the debt (#3189)")
@MainActor
struct LaunchRidersLedgerTests {
    private static let app = "app.launched"
    private static let rider = LaunchRiders.Rider(
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

    @Test("a rider is taken once, by its own app")
    func takenOnce() {
        let ledger = Self.owing()
        #expect(ledger.takeRiders(of: Self.app) == [Self.rider])
        #expect(ledger.takeRiders(of: Self.app).isEmpty)
        // Another app's payment takes none, and drops them.
        let other = Self.owing()
        #expect(other.takeRiders(of: "app.other").isEmpty)
        #expect(other.takeRiders(of: Self.app).isEmpty)
    }

    @Test("the claim leaves the riders for its payment")
    func claimKeepsRiders() {
        let ledger = Self.owing()
        #expect(ledger.claim(Self.app, at: Self.now))
        #expect(ledger.takeRiders(of: Self.app) == [Self.rider])
    }

    @Test("no debt, or another app's, notes nothing")
    func unowedNotesNothing() {
        let ledger = LaunchFollowIntent()
        ledger.noteRider(Self.rider, of: Self.app, at: Self.now)
        #expect(ledger.takeRiders(of: Self.app).isEmpty)
        ledger.record("app.other", at: Self.now)
        ledger.noteRider(Self.rider, of: Self.app, at: Self.now)
        #expect(ledger.takeRiders(of: Self.app).isEmpty)
    }

    @Test("every ender of the debt retires its riders")
    func endersRetire() {
        let late = Self.now.addingTimeInterval(
            LaunchFollowIntent.drainWindow
        )
        let enders: [(String, (LaunchFollowIntent) -> Void)] = [
            ("a new debt", { $0.record(Self.app, at: Self.now) }),
            ("expiry", { _ = $0.owed(at: late) }),
            ("a refused open", { $0.forget(pending: Self.app) }),
            ("another activation", { $0.forget(keeping: "app.other") }),
            ("a Desktop switch", { $0.forget() }),
        ]
        for (name, end) in enders {
            let ledger = Self.owing()
            end(ledger)
            #expect(
                ledger.takeRiders(of: Self.app).isEmpty,
                "\(name) left riders"
            )
        }
        // The control: another app's refused open ends nothing.
        let ledger = Self.owing()
        ledger.forget(pending: "app.other")
        #expect(ledger.takeRiders(of: Self.app) == [Self.rider])
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
}
