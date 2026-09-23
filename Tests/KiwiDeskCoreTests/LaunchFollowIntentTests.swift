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
        intent.record(7, at: t0)
        #expect(!intent.claim(8, at: t0))
        #expect(intent.claim(7, at: t0))
        #expect(!intent.claim(7, at: t0))
    }

    @Test("A debt past its bound is dropped unpaid")
    func expires() {
        let intent = LaunchFollowIntent()
        intent.record(7, at: t0)
        let inside = t0.addingTimeInterval(
            LaunchFollowIntent.drainWindow - 0.01
        )
        #expect(intent.owed(at: inside) == 7)
        let past = t0.addingTimeInterval(
            LaunchFollowIntent.drainWindow + 0.01
        )
        #expect(!intent.claim(7, at: past))
        #expect(intent.owed(at: inside) == nil)
    }

    @Test("The bound outlasts one adoption-heal period after a launch")
    func boundCoversTheHeal() {
        // A launch's first window is adopted by the heal as late
        // as 6.3 s after its activation (#1599): the follow's own
        // five seconds alone would drop it.
        #expect(
            LaunchFollowIntent.drainWindow
                >= FollowFocusIntent.drainWindow
                + TimeInterval(
                    KiwiCore.adoptionHealDefault.components.seconds
                )
        )
        #expect(LaunchFollowIntent.drainWindow > 6.3)
    }

    @Test("A later record replaces; forget retires")
    func replaceAndForget() {
        let intent = LaunchFollowIntent()
        intent.record(7, at: t0)
        intent.record(8, at: t0)
        #expect(!intent.claim(7, at: t0))
        #expect(intent.owed(at: t0) == 8)
        intent.forget()
        #expect(intent.owed(at: t0) == nil)
    }
}
