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
    private func withOff(_ body: () -> Void) {
        let system = ReduceMotion.systemOverride
        ReduceMotion.systemOverride = false
        ReduceMotion.kiwiDesk = true
        defer {
            ReduceMotion.kiwiDesk = false
            ReduceMotion.systemOverride = system
        }
        body()
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
                args: []
            ).isSuccess
        )
    }

    /// The engine on the home, as Bootstrap wires it
    /// (`ReduceMotionHomeTests` ▸ `gatesAreWired`): under Off a
    /// frame change lands at once, and no animation is left running.
    @Test("the engine starts no animation under Off")
    func engineStartsNothing() throws {
        let screen = try #require(NSScreen.screens.first)
        let engine = AnimationEngine()
        engine.reduceMotion = { ReduceMotion.isOn }
        var landed: [(WindowID, CGRect, Bool)] = []
        engine.apply = { landed.append(($0, $1, $2)) }
        let target = CGRect(x: 100, y: 100, width: 400, height: 300)
        withOff {
            engine.animate(
                window: WindowID(7),
                on: screen,
                from: CGRect(x: 0, y: 0, width: 300, height: 200),
                to: target
            )
        }
        #expect(landed.count == 1)
        #expect(landed.first?.1 == target)
        #expect(landed.first?.2 == true)
        let running = engine.animations.values.reduce(0) { $0 + $1.count }
        #expect(running == 0)
    }

    /// Off is a Reduce Motion read, so a Slide pick falls back to
    /// Show the Space through the one `drawn(reduceMotion:)`; the
    /// overlays' default reads the home (`gatesAreWired`).
    @Test("a Slide pick draws Show the Space under Off")
    func slideFallsBack() {
        let saved = BarMotion.reducedOverride
        BarMotion.reducedOverride = nil
        defer { BarMotion.reducedOverride = saved }
        withOff {
            #expect(BarMotion.isReduced)
            let drawn = SpaceTransition.slide.drawn(
                reduceMotion: BarMotion.isReduced
            )
            #expect(drawn == .show)
        }
    }
}
