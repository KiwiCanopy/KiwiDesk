import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiDesk's own Off (#3238) reaches the one Reduce Motion read and
/// every gate that asks it: the window engine starts no animation,
/// the Space slide draws Show the Space, the bars' gate reads
/// reduced. `ReduceMotion.kiwiDesk` is process-global, so each test
/// pins the OS read, sets the flag for its body alone and puts both
/// back.
@Suite("KiwiDesk's own Reduce Motion (#3238)", .serialized)
@MainActor
struct ReduceMotionFlagTests {
    private func withOff(_ body: () throws -> Void) rethrows {
        ReduceMotion.systemOverride = false
        ReduceMotion.kiwiDesk = true
        defer {
            ReduceMotion.kiwiDesk = false
            ReduceMotion.systemOverride = nil
        }
        try body()
    }

    @Test("the read ORs the flag into macOS's")
    func readJoinsBoth() {
        ReduceMotion.systemOverride = false
        defer { ReduceMotion.systemOverride = nil }
        #expect(!ReduceMotion.isOn)
        withOff { #expect(ReduceMotion.isOn) }
        #expect(!ReduceMotion.isOn)
    }

    /// The verb writes the session value, and the live change sets
    /// the flag the read takes.
    @Test("the verb turns the flag on and off")
    func verbSetsTheFlag() {
        let core = makeTestCore()
        defer { ReduceMotion.kiwiDesk = false }
        #expect(
            core.execute(
                "animations.set_reduce_motion",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.appWide.animationReduceMotion)
        #expect(ReduceMotion.kiwiDesk)
        #expect(
            core.execute(
                "animations.set_reduce_motion",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!ReduceMotion.kiwiDesk)
        #expect(
            !core.execute(
                "animations.set_reduce_motion",
                args: [.string("on")]
            ).isSuccess
        )
    }

    /// The engine's gate as Bootstrap wires it: under Off a frame
    /// change lands at once, with no animation started.
    @Test("the engine starts no animation under Off")
    func engineStartsNothing() {
        let engine = AnimationEngine()
        engine.reduceMotion = { ReduceMotion.isOn }
        withOff { #expect(engine.reduceMotion()) }
        ReduceMotion.systemOverride = false
        defer { ReduceMotion.systemOverride = nil }
        #expect(!engine.reduceMotion())
    }

    /// The overlays' default gate is the bars' one, which reads the
    /// home: a Slide pick draws Show the Space under Off.
    @Test("the Space slide draws Show the Space under Off")
    func slideFallsBack() {
        BarMotion.reducedOverride = nil
        withOff {
            #expect(BarMotion.isReduced)
            let drawn = SpaceTransition.slide.drawn(
                reduceMotion: BarMotion.isReduced
            )
            #expect(drawn == .show)
        }
    }
}
