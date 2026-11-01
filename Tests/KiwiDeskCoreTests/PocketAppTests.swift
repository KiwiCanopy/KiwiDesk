import Foundation
import Testing

@testable import KiwiDeskCore

/// `pocket_app` (#2612): the app's own key opens a fresh window of
/// the app, which arrives out and tied to it while its row exists,
/// then puts that window away and takes it out; the general list
/// steps past it and its capacity never counts it.
@Suite("pocket_app", .serialized)
@MainActor
struct PocketAppTests {
    typealias Fixture = PocketAppFixture
    private let mine = WindowID(9)

    @Test("an unknown app opens nothing and claims nothing")
    func unknownApp() {
        let fixture = Fixture()
        let response = fixture.press("app.nope")
        #expect(response.error == "app not found: app.nope")
        #expect(fixture.core.arrivals.pocketClaim == nil)
    }

    @Test("the first press launches the app; its window arrives out")
    func firstPressArrivesOut() {
        let fixture = Fixture()
        #expect(fixture.press("App.Test").isSuccess)
        #expect(fixture.opened == [Fixture.app])
        fixture.arrive(9)
        let state = fixture.core.state
        #expect(state.pocketPhase(of: mine) == .out)
        #expect(state.pocketKeyOwner(of: mine) == Fixture.app)
        #expect(state.windows[mine]?.isFloating == true)
        #expect(fixture.core.arrivals.pocketClaim == nil)
    }

    @Test("later presses put it away and take it out")
    func pressesStepTheWindow() {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9)
        fixture.press()
        #expect(fixture.core.state.isPocketed(mine))
        fixture.press()
        #expect(fixture.core.state.pocketPhase(of: mine) == .out)
        #expect(fixture.opened.count == 1)
    }

    @Test("a running app with windows gets its New Window pressed")
    func runningAppPressesNewWindow() {
        let fixture = Fixture()
        fixture.running = Fixture.pid
        fixture.visible = 1
        fixture.press()
        #expect(fixture.pressed == [Fixture.pid])
        #expect(fixture.opened.isEmpty)
        #expect(fixture.core.arrivals.pocketClaim != nil)
    }

    @Test("a press that opened nothing drops the claim")
    func refusedPressDropsTheClaim() {
        let fixture = Fixture()
        fixture.running = Fixture.pid
        fixture.visible = 1
        fixture.pressAnswers = false
        fixture.press()
        #expect(fixture.core.arrivals.pocketClaim == nil)
    }

    @Test("with no row the window joins the general list")
    func noRowIsGeneral() {
        let fixture = Fixture(row: false)
        fixture.press()
        fixture.arrive(9)
        #expect(fixture.core.state.pocketPhase(of: mine) == .out)
        #expect(fixture.core.state.pocketKeyOwner(of: mine) == nil)
    }

    @Test("with no row and one window taken, the press opens nothing")
    func noRowRespectsTheCapacity() {
        let fixture = Fixture(row: false)
        #expect(fixture.core.execute("toggle_pocket_window").isSuccess)
        let response = fixture.press()
        #expect(response.error == "another window is the pocket window")
        #expect(fixture.opened.isEmpty)
    }

    @Test("a keyed window is outside the capacity")
    func keyedIsOutsideTheCapacity() {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9)
        fixture.core.state.apply(.windowFocused(WindowID(1)))
        #expect(fixture.core.execute("toggle_pocket_window").isSuccess)
        #expect(fixture.core.state.pocketPhase(of: WindowID(1)) == .out)
    }

    @Test("a general verb on the keyed window is refused")
    func generalVerbsRefuse() {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9)
        fixture.core.state.apply(.windowFocused(mine))
        let toggle = fixture.core.execute("toggle_pocket_window")
        #expect(toggle.error == "this window has a Pocket key of its own")
        let named = fixture.core.execute("pocket", args: [.number(9)])
        #expect(named.error == "this window has a Pocket key of its own")
        #expect(fixture.core.state.pocketPhase(of: mine) == .out)
    }

    @Test("pocket steps past the keyed window")
    func pocketStepsPast() {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9)
        fixture.press()
        fixture.core.state.apply(.windowFocused(WindowID(1)))
        #expect(fixture.core.execute("pocket").isSuccess)
        // The general list was empty: the press pocketed the focus.
        #expect(fixture.core.state.isPocketed(WindowID(1)))
        #expect(fixture.core.state.isPocketed(mine))
    }
}
