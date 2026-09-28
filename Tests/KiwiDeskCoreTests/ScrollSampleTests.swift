import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A tap event's raw fields become a `ScrollSample` (#1656): the
/// four modifiers alone, the documented phase values, and the
/// delta in the natural convention whatever macOS says.
@Suite("Scroll sample reading")
struct ScrollSampleTests {
    private func sample(
        flags: CGEventFlags = [],
        inverted: Bool,
        phase: Int64 = 0,
        momentum: Int64 = 0
    ) -> ScrollSample {
        ScrollSample(
            flags: flags,
            pointDeltaX: 3,
            pointDeltaY: -7,
            invertedBySystem: inverted,
            scrollPhase: phase,
            momentumPhase: momentum,
            location: CGPoint(x: 4, y: 5)
        )
    }

    @Test("the system's inversion is undone")
    func naturalConvention() {
        #expect(sample(inverted: true).delta == CGVector(dx: 3, dy: -7))
        #expect(sample(inverted: false).delta == CGVector(dx: -3, dy: 7))
    }

    @Test("only ⌃⌥⌘⇧ count as the chord")
    func fourModifiersOnly() {
        let flags: CGEventFlags = [
            .maskControl, .maskAlternate, .maskCommand, .maskShift,
            .maskAlphaShift, .maskSecondaryFn, .maskNumericPad,
        ]
        #expect(
            sample(flags: flags, inverted: true).chord
                == [.control, .option, .command, .shift]
        )
        #expect(
            sample(flags: [.maskSecondaryFn], inverted: true).chord
                .isEmpty
        )
    }

    @Test("phase and momentum values map to their cases")
    func phases() {
        let phases: [Int64: ScrollSample.Phase] = [
            0: .none, 1: .began, 2: .changed, 4: .ended,
            8: .cancelled, 128: .mayBegin, 99: .none,
        ]
        for (raw, phase) in phases {
            #expect(sample(inverted: true, phase: raw).phase == phase)
        }
        let momenta: [Int64: ScrollSample.Momentum] = [
            0: .none, 1: .began, 2: .changed, 3: .ended, 9: .none,
        ]
        for (raw, momentum) in momenta {
            #expect(
                sample(inverted: true, momentum: raw).momentum
                    == momentum
            )
        }
    }
}

/// The tap reads a real `CGEvent`'s fields into its sample: axis
/// 2 is horizontal, axis 1 vertical, phases from their fields.
@Suite("Scroll tap event reading")
struct ScrollTapEventReadingTests {
    @Test("the tap listens to the scroll wheel and nothing else")
    func maskIsScrollOnly() {
        #expect(ScrollGestureTap.mask == 1 << 22)
        #expect(CGEventType.scrollWheel.rawValue == 22)
    }

    @Test("axes, phases and flags come off the event")
    func readsTheEvent() throws {
        let event = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: 7,
                wheel2: -3,
                wheel3: 0
            )
        )
        event.flags = [.maskControl, .maskAlternate]
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
        event.setIntegerValueField(
            .scrollWheelEventMomentumPhase,
            value: 2
        )
        let sample = ScrollGestureTap.sample(of: event)
        #expect(sample.chord == [.control, .option])
        #expect(sample.phase == .ended)
        #expect(sample.momentum == .changed)
        // A synthetic event is not inverted by the system, so the
        // natural convention negates both axes.
        #expect(sample.delta == CGVector(dx: 3, dy: -7))
    }
}
