import Foundation
import Testing

@testable import KiwiDeskCore

/// The launch follow's ledger (#1599): keyed by app, paid once,
/// bounded, replaced and retired. `LaunchFollowTests` drives it
/// through the core; this holds the record on an explicit clock.
@Suite("Launch follow ledger (#1599)")
@MainActor
struct LaunchFollowIntentTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test("The owing app claims once; another app never does")
    func claimsOnceForItsApp() {
        let intent = LaunchFollowIntent()
        intent.record("app.a", at: t0)
        #expect(!intent.claim("app.b", at: t0))
        #expect(intent.claim("app.a", at: t0))
        #expect(!intent.claim("app.a", at: t0))
    }

    @Test("A debt past its bound is dropped unpaid")
    func expires() {
        let intent = LaunchFollowIntent()
        intent.record("app.a", at: t0)
        let inside = t0.addingTimeInterval(
            LaunchFollowIntent.drainWindow - 0.01
        )
        #expect(intent.owed(at: inside) == "app.a")
        let past = t0.addingTimeInterval(
            LaunchFollowIntent.drainWindow + 0.01
        )
        #expect(!intent.claim("app.a", at: past))
        #expect(intent.owed(at: inside) == nil)
    }

    @Test("The bound outlasts the slowest measured launch adoption")
    func boundCoversTheHeal() {
        // A launch's first window was adopted by the heal 6.3 s
        // after its activation (#1599).
        #expect(LaunchFollowIntent.drainWindow > 6.3)
    }

    @Test("A later record replaces; forget retires")
    func replaceAndForget() {
        let intent = LaunchFollowIntent()
        intent.record("app.a", at: t0)
        intent.record("app.b", at: t0)
        #expect(!intent.claim("app.a", at: t0))
        #expect(intent.owed(at: t0) == "app.b")
        intent.forget()
        #expect(intent.owed(at: t0) == nil)
    }
}
