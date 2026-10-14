import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The `KIWIDESK_NO_WS_TRACKING` QA lever (#596): the settle-tail
/// symptoms are AX-fallback-only, and the WindowServer stream is
/// up on every developer Mac, so the fallback path needs a way to
/// be forced on a healthy machine.
@Suite("WindowServer tracking lever")
@MainActor
struct BorderTrackingLeverTests {
    @Test("Any non-empty value arms the lever; absent leaves it off")
    func environmentDecode() {
        let watch = WindowServerWatch()
        watch.configureFromEnvironment([:])
        #expect(!watch.trackingDisabled)
        // Present-but-empty is "not set" (the strand detector's
        // rule, mirrored) — `env VAR= app` must not arm it.
        watch.configureFromEnvironment([
            "KIWIDESK_NO_WS_TRACKING": ""
        ])
        #expect(!watch.trackingDisabled)
        watch.configureFromEnvironment([
            "KIWIDESK_NO_WS_TRACKING": "1"
        ])
        #expect(watch.trackingDisabled)
    }

    @Test("Armed, the subscription never attaches or goes active")
    func subscriptionStandsDown() {
        let watch = WindowServerWatch()
        watch.onLog = { _ in }
        let border = BorderManager(watch: watch)
        border.movePanel = { _, _ in false }
        watch.configureFromEnvironment([
            "KIWIDESK_NO_WS_TRACKING": "yes"
        ])
        // Past the dormant-runtime guard, so the lever is what
        // holds the stream down — not the unit-test environment.
        watch.start()
        watch.request([WindowID(1)], for: .ring)
        watch.request([WindowID(1)], for: .mark)
        #expect(!watch.isActive)
        // No attach: a live subscription would keep feeding the
        // ring, healing the drift the lever exposes.
        #expect(!watch.triedSource)
        // And the predicates every consumer reads follow it down,
        // so the AX echo becomes the ring's and mark's carrier.
        #expect(!border.usesWindowServerTracking(WindowID(1)))
        #expect(!watch.hears(WindowID(1), as: .mark))
        watch.stop()
    }
}
