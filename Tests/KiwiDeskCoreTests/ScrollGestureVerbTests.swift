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

    @Test("set_pan writes the base and reaches the tap")
    func setPan() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "scroll_gesture.set_pan",
                args: [.string("command+shift")]
            ).isSuccess
        )
        #expect(core.mouse.scroll.base.pan == [.command, .shift])
        #expect(tapChords(core).chords[.pan] == [.command, .shift])
    }

    @Test("empty turns a gesture off")
    func emptyIsOff() {
        let core = makeTestCore()
        #expect(
            core.execute("scroll_gesture.set_space_step", args: [.string("")])
                .isSuccess
        )
        #expect(tapChords(core).chords[.step] == nil)
    }

    @Test(
        "one modifier alone, an unknown one, or the other's chord is refused"
    )
    func refusals() {
        let core = makeTestCore()
        for bad in ["control", "shift", "control+fn"] {
            #expect(
                !core.execute("scroll_gesture.set_pan", args: [.string(bad)])
                    .isSuccess
            )
        }
        #expect(
            !core.execute(
                "scroll_gesture.set_pan",
                args: [.string("control+option+command")]
            ).isSuccess
        )
        #expect(core.mouse.scroll.base == .defaults)
    }

    @Test("Natural scrolling is a boolean on the base")
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

    @Test("a profile's override outranks the base a verb writes")
    func overrideOutranksVerb() {
        let core = makeTestCore()
        core.applyScrollGestures(
            base: .defaults,
            profile: ScrollGestureOverride(pan: [.control, .shift])
        )
        #expect(
            core.execute(
                "scroll_gesture.set_pan",
                args: [.string("command+option")]
            ).isSuccess
        )
        #expect(core.mouse.scroll.base.pan == [.command, .option])
        #expect(tapChords(core).chords[.pan] == [.control, .shift])
    }

    @Test("a profile apply keeps the base and swaps the override")
    func profileApplyKeepsBase() {
        let core = makeTestCore()
        var base = ScrollGestureBase.defaults
        base.naturalTrackpad = false
        core.applyScrollGestures(base: base, profile: nil)
        core.applyScrollGestures(
            profile: ScrollGestureOverride(spaceStep: [])
        )
        #expect(!tapChords(core).naturalTrackpad)
        #expect(tapChords(core).chords[.step] == nil)
        core.applyScrollGestures(profile: nil)
        #expect(
            tapChords(core).chords[.step] == [.control, .option, .command]
        )
    }

    /// The verb writes the base and the live profile resolves over
    /// it, so the other gesture's chord in EITHER is refused.
    @Test("the other gesture's base and resolved chords are refused")
    func refusalReadsBothOthers() {
        let core = makeTestCore()
        core.applyScrollGestures(
            base: .defaults,
            profile: ScrollGestureOverride(spaceStep: [.command, .shift])
        )
        #expect(
            !core.execute(
                "scroll_gesture.set_pan",
                args: [.string("command+shift")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "scroll_gesture.set_pan",
                args: [.string("control+option+command")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "scroll_gesture.set_pan",
                args: [.string("command+option")]
            ).isSuccess
        )
    }
}
