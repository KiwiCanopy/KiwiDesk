import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The `KIWIDESK_NO_WS_TRACKING` QA lever (#596): the settle-tail
/// symptoms are AX-fallback-only, and the WindowServer stream is
/// up on every developer Mac, so the fallback path needs a way to
/// be forced on a healthy machine.
@Suite("Border WindowServer tracking lever")
@MainActor
struct BorderTrackingLeverTests {
    @Test("Any non-empty value arms the lever; absent leaves it off")
    func environmentDecode() {
        let border = BorderManager()
        border.configureFromEnvironment([:])
        #expect(!border.windowServerTrackingDisabled)
        // Present-but-empty is "not set" (the strand detector's
        // rule, mirrored) — `env VAR= app` must not arm it.
        border.configureFromEnvironment([
            "KIWIDESK_NO_WS_TRACKING": ""
        ])
        #expect(!border.windowServerTrackingDisabled)
        border.configureFromEnvironment([
            "KIWIDESK_NO_WS_TRACKING": "1"
        ])
        #expect(border.windowServerTrackingDisabled)
    }

    @Test("Armed, the subscription never attaches or goes active")
    func subscriptionStandsDown() {
        let border = BorderManager()
        border.configureFromEnvironment([
            "KIWIDESK_NO_WS_TRACKING": "yes"
        ])
        // Past the dormant-runtime guard, so the lever is what
        // holds the stream down — not the unit-test environment.
        border.start()
        border.skyLightActive = true
        border.updateSkyLightSubscription([WindowID(1)])
        #expect(!border.skyLightActive)
        // No attach: a live subscription would keep feeding
        // `reconcile`, healing the drift the lever exposes.
        #expect(!border.triedEventSource)
        // And the predicates both consumers read follow it down,
        // so the AX echo becomes the ring's and mark's carrier.
        #expect(!border.usesWindowServerTracking(WindowID(1)))
        #expect(!border.markUsesWindowServerTracking(WindowID(1)))
        border.stop()
    }
}
