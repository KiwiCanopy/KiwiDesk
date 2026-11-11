import Foundation
import Testing

@testable import KiwiDeskCore

/// `scroll_gesture.*` and the one resolve home (#1656): verbs write
/// the base, a profile's override outranks it, and the tap is
/// configured with the resolved value.
@Suite("Scroll gesture verbs", .serialized)
@MainActor
struct ScrollGestureVerbTests {
    private func tapChords(_ core: KiwiCore) -> ScrollGestureSettings {
        core.mouse.scroll.settings
    }

    @Test("Natural scrolling is a boolean or \"system\" on the base")
    func naturalScrolling() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!tapChords(core).naturalTrackpad)
        #expect(!tapChords(core).naturalMouse)
        #expect(
            core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.bool(true), .string("mouse")]
            ).isSuccess
        )
        #expect(!tapChords(core).naturalTrackpad)
        #expect(tapChords(core).naturalMouse)
        #expect(
            core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.string("system"), .string("trackpad")]
            ).isSuccess
        )
        #expect(core.mouse.scroll.base.naturalTrackpad == .system)
        #expect(
            !core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.string("no")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.bool(true), .string("pen")]
            ).isSuccess
        )
    }

}
