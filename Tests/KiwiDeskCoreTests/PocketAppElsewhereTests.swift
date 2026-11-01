import Foundation
import Testing

@testable import KiwiDeskCore

/// A running app showing no window here (#2612, device QA
/// 2026-11-01): its windows may sit on another Desktop, where a
/// reopen only brings one forward and opens nothing, so the key
/// presses its New Window row without activating it, and reopens
/// only where the app has no such row.
@Suite("Pocket ▸ app with no window here", .serialized)
@MainActor
struct PocketAppElsewhereTests {
    private typealias Fixture = PocketAppFixture

    private func runningWithNoWindowHere() -> Fixture {
        let fixture = Fixture()
        fixture.running = Fixture.pid
        return fixture
    }

    @Test("its New Window row is pressed, the app not activated")
    func pressesNewWindow() {
        let fixture = runningWithNoWindowHere()
        #expect(fixture.press().isSuccess)
        #expect(fixture.pressed == [Fixture.pid])
        #expect(fixture.opened.isEmpty)
        #expect(fixture.activated.isEmpty)
        #expect(fixture.claim != nil)
    }

    @Test("an app with no such row is reopened, its claim kept")
    func noRowReopens() {
        let fixture = runningWithNoWindowHere()
        fixture.pressAnswers = false
        fixture.press()
        #expect(fixture.opened == [Fixture.app])
        #expect(fixture.claim != nil)
    }

    @Test("an app showing a window is activated before the press")
    func showingAppIsActivated() {
        let fixture = runningWithNoWindowHere()
        fixture.visible = 1
        fixture.press()
        #expect(fixture.activated == [Fixture.pid])
        #expect(fixture.pressed == [Fixture.pid])
    }
}
