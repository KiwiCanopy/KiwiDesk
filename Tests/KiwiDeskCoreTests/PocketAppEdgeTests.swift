import Foundation
import Testing

@testable import KiwiDeskCore

/// `pocket_app`'s edges (#2612): the tie is judged at the claim's
/// spend against the row as it then stands, a keyed press and
/// arrival pass a taken general list, a full-screen arrival is
/// never claimed, and a hidden app's key shows the app.
@Suite("pocket_app edges", .serialized)
@MainActor
struct PocketAppEdgeTests {
    typealias Fixture = PocketAppFixture
    private let mine = WindowID(9)

    @Test("a full-screen arrival is not claimed")
    func fullscreenIsNotClaimed() {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9, fullscreen: true)
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
        #expect(fixture.claim != nil)
    }

    @Test("a row installed after a rowless press ties nothing")
    func rowAfterThePressTiesNothing() {
        let fixture = Fixture(row: false)
        fixture.press()
        fixture.installRow(true)
        fixture.arrive(9)
        #expect(fixture.core.state.pocketPhase(of: mine) == .out)
        #expect(fixture.owner(of: mine) == nil)
    }

    @Test("a row removed before the arrival ties nothing")
    func rowGoneBeforeTheArrival() {
        let fixture = Fixture()
        fixture.press()
        fixture.installRow(false)
        fixture.arrive(9)
        #expect(fixture.owner(of: mine) == nil)
    }

    @Test("a keyed press and arrival pass a taken general list")
    func keyedPassesTheCapacity() {
        let fixture = Fixture()
        #expect(fixture.core.execute("toggle_pocket_window").isSuccess)
        #expect(fixture.press().isSuccess)
        #expect(fixture.opened == [Fixture.app])
        fixture.arrive(9)
        #expect(fixture.owner(of: mine) == Fixture.app)
    }

    @Test("a hidden app's key shows the app")
    func hiddenAppIsShown() {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9)
        fixture.core.eventLoop.processIdentity.runs = { _ in true }
        fixture.core.eventLoop.onEvent(.windowHidden(mine))
        #expect(fixture.core.state.pocketSlot(of: mine) != nil)
        #expect(fixture.press().isSuccess)
        #expect(fixture.activated.contains(Fixture.pid))
    }

    @Test("the row is found whatever the bundle id's case")
    func rowLookupIgnoresCase() {
        let fixture = Fixture()
        #expect(fixture.core.pocketAppRow(for: "App.Test") != nil)
    }
}
