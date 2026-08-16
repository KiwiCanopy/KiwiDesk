import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The `displayFingerprints` probe's twin, for the session seam
/// (#835). Unwired the seam reports "unknown" on every axis
/// forever, which reads as a plausible diagnostic line rather
/// than a broken one — nothing in the log says the seam was never
/// connected, so the next captured cycle would be decided by a
/// fact nobody measured.
///
/// Two things it deliberately does NOT do.
///
/// It does not assert a host value: what macOS reports depends on
/// where the suite runs, and a runner with no console session is
/// entitled to answer `nil` on every axis — which is the inert
/// default, making the seam unobservable there.
///
/// `.enabled(if:)`, not an in-test `#require`: a `#require` that
/// fails records an expectation failure and reports the test
/// FAILED, so a screenless or session-less runner would go red
/// with the wiring perfectly correct. The trait reports a SKIP,
/// which is the honest answer (the `ZOrderFocusJumpTests`
/// precedent) — and read that skip as what it is: on such a
/// runner a green run is not coverage of this seam, so a CI pass
/// alone never proves the wiring survived.
///
/// And it cannot see a seam FROZEN at bootstrap — a captured
/// `.live()` reads identically here and reports the session as it
/// was before any lock. `WakeSessionSeamWiringTests` needles the
/// closure body for that; this suite proves the seam is connected
/// at all, which a source needle cannot.
@Suite(
    "WakeSessionPresenceWiringTests",
    .enabled(
        if: SessionPresence.live() != SessionPresence(session: nil)
    )
)
@MainActor
struct WakeSessionPresenceWiringTests {
    @Test("Bootstrap wires the seam to the live session read")
    func seamIsNotTheInertDefault() {
        let core = makeTestCore()
        #expect(
            core.sleepWake.sessionPresence()
                != SessionPresence(session: nil)
        )
    }
}
