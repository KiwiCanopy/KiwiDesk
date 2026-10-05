import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The plate slide's held writes (#1956): a write to an incoming
/// window waits for the strip to land, and leaves once — the
/// latest frame, a size set never dropped.
@Suite("Held frame writes (#1956)")
struct HeldWritesTests {
    private let w = WindowID(7)
    private let a = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let b = CGRect(x: 50, y: 0, width: 100, height: 100)
    private let t0 = DispatchTime(uptimeNanoseconds: 1_000_000_000)

    private func later(_ seconds: Double) -> DispatchTime {
        t0 + seconds
    }

    @Test("a window nobody holds writes at once")
    func unheldPasses() {
        let held = HeldWrites()
        #expect(held.stage(w, a, setSize: true, now: t0) == .pass)
    }

    @Test("a held window stages, then folds later writes into it")
    func heldStagesAndMerges() {
        let held = HeldWrites()
        held.hold([w], until: later(0.4))
        #expect(
            held.stage(w, a, setSize: true, now: t0) == .staged(later(0.4))
        )
        #expect(held.stage(w, b, setSize: false, now: t0) == .merged)
        // Too early: the release waits.
        #expect(held.release(w, now: later(0.1)) == .later(later(0.4)))
        #expect(
            held.release(w, now: later(0.4))
                == .write(HeldWrites.Entry(frame: b, setSize: true))
        )
        // Once.
        #expect(held.release(w, now: later(0.5)) == HeldWrites.Release.none)
        #expect(held.stage(w, a, setSize: false, now: later(0.5)) == .pass)
    }

    @Test("a burst holding the window again takes the later landing")
    func reholdTakesTheLater() {
        let held = HeldWrites()
        held.hold([w], until: later(0.4))
        _ = held.stage(w, a, setSize: false, now: t0)
        held.hold([w], until: later(0.7))
        held.hold([w], until: later(0.5))
        #expect(held.release(w, now: later(0.4)) == .later(later(0.7)))
        #expect(held.isHeld(w, now: later(0.6)))
        #expect(!held.isHeld(w, now: later(0.7)))
    }

    @Test("a hold past its deadline stages nothing")
    func expiredHoldPasses() {
        let held = HeldWrites()
        held.hold([w], until: later(0.4))
        #expect(held.stage(w, a, setSize: false, now: later(0.4)) == .pass)
    }
}
