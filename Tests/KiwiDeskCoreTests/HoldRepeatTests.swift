import Foundation
import Testing

@testable import KiwiDeskCore

/// The hold-to-repeat ladder (#1056), machine-only: every seam
/// injected, no timers, no Carbon, no Lua. The production
/// wiring — a real chord driving a real `resize` through
/// `KiwiCore.execute`'s tally — is `HoldRepeatWiringTests`,
/// which is what reds if the tally call is deleted; this suite
/// cannot see that and does not claim to.
@MainActor
@Suite("Hold-to-repeat ladder (#1056)")
struct HoldRepeatTests {
    /// A machine with captured scheduling and firing: `ticks`
    /// holds each scheduled (delay, work) pair, `fired` each
    /// re-fire request, and the timings are constants so no
    /// test reads the host's key-repeat preferences.
    @MainActor
    private final class Harness {
        let repeatEngine = HoldRepeat()
        var ticks: [(delay: TimeInterval, work: () -> Void)] =
            []
        var cancels = 0
        var fired: [UInt32] = []
        var overruns = 0

        init(releaseCapable: Bool = true) {
            repeatEngine.releaseCapable = releaseCapable
            repeatEngine.initialDelay = { 0.5 }
            repeatEngine.interval = { 0.1 }
            repeatEngine.schedule = { [weak self] delay, work in
                self?.ticks.append((delay, work))
                return { self?.cancels += 1 }
            }
            repeatEngine.fire = { [weak self] id in
                self?.fired.append(id)
            }
            repeatEngine.onOverrun = { [weak self] in
                self?.overruns += 1
            }
        }

        /// One press-fire that ran exactly the given commands.
        func press(
            id: UInt32,
            commands: [(String, Bool)] = [("resize", true)]
        ) {
            _ = repeatEngine.beginFire()
            for (name, ok) in commands {
                repeatEngine.noteCommand(name, succeeded: ok)
            }
            repeatEngine.endFire(id: id, press: true)
        }

        /// Runs the pending tick as a fire of the given
        /// commands — the shape `fireRepeatTick` drives. The
        /// `#require` is load-bearing (guard-prover, #1056): a
        /// regression that stops scheduling must fail THIS
        /// test, not trap the whole runner on an empty array.
        func runTick(
            id: UInt32,
            commands: [(String, Bool)] = [("resize", true)]
        ) throws {
            let popped = ticks.popLast()
            let tick = try #require(popped)
            tick.work()
            _ = repeatEngine.beginFire()
            for (name, ok) in commands {
                repeatEngine.noteCommand(name, succeeded: ok)
            }
            repeatEngine.endFire(id: id, press: false)
        }
    }

    @Test("One successful resize arms; ticks ride the interval")
    func armsAndTicks() throws {
        let h = Harness()
        h.press(id: 7)
        #expect(h.repeatEngine.heldID == 7)
        #expect(h.ticks.map(\.delay) == [0.5])
        try h.runTick(id: 7)
        // The tick re-fired the binding and the run went on at
        // the repeat interval, not the initial delay.
        #expect(h.fired == [7])
        #expect(h.ticks.map(\.delay) == [0.1])
    }

    @Test("Ineligible presses never arm")
    func ineligiblePressesNeverArm() {
        // A verb outside the repeatable set (overshooting focus
        // is worse than pressing again).
        let focus = Harness()
        focus.press(id: 1, commands: [("focus", true)])
        #expect(focus.repeatEngine.heldID == nil)
        #expect(focus.ticks.isEmpty)

        // A body running MORE than the one command: repeating
        // the rest of it was never asked for.
        let two = Harness()
        two.press(
            id: 1,
            commands: [("resize", true), ("focus", true)]
        )
        #expect(two.repeatEngine.heldID == nil)

        // A failed resize (unsupported layout) would beep per
        // tick.
        let failed = Harness()
        failed.press(id: 1, commands: [("resize", false)])
        #expect(failed.repeatEngine.heldID == nil)

        // No release channel: a run could never stop.
        let deaf = Harness(releaseCapable: false)
        deaf.press(id: 1)
        #expect(deaf.repeatEngine.heldID == nil)
    }

    @Test("A refusal cues once and ends the run")
    func refusalEndsTheRun() throws {
        // At the wall on the FIRST press: the pill flashed
        // once, and holding must not flash it per tick.
        let atWall = Harness()
        _ = atWall.repeatEngine.beginFire()
        atWall.repeatEngine.noteCommand(
            "resize",
            succeeded: true
        )
        atWall.repeatEngine.noteRefusal()
        atWall.repeatEngine.endFire(id: 1, press: true)
        #expect(atWall.repeatEngine.heldID == nil)
        #expect(atWall.ticks.isEmpty)

        // Reaching the wall MID-run: the tick that hit it is
        // the last. Belt-and-braces by design (guard-prover,
        // #1056): `noteRefusal`'s own cancel AND `endFire`'s
        // `!refused` term each stop this alone, so no single
        // mutation reds this leg — the at-wall leg above pins
        // the eligibility term, and `HoldRepeatWiringTests`
        // pins the out-of-bracket cancel. Read this leg as the
        // contract's statement, not as its net.
        let run = Harness()
        run.press(id: 2)
        let poppedTick = run.ticks.popLast()
        let tick = try #require(poppedTick)
        tick.work()
        _ = run.repeatEngine.beginFire()
        run.repeatEngine.noteCommand("resize", succeeded: true)
        run.repeatEngine.noteRefusal()
        run.repeatEngine.endFire(id: 2, press: false)
        #expect(run.repeatEngine.heldID == nil)
        #expect(run.ticks.isEmpty)
    }

    @Test("Release ends the run; a stale release is ignored")
    func releaseStopsTheRun() {
        let h = Harness()
        h.press(id: 3)
        // A release for some OTHER id (a run already replaced)
        // must not touch this one.
        h.repeatEngine.released(id: 99)
        #expect(h.repeatEngine.heldID == 3)
        h.repeatEngine.released(id: 3)
        #expect(h.repeatEngine.heldID == nil)
        #expect(h.cancels == 1)
    }

    @Test("A new press replaces the previous run")
    func newPressReplacesTheRun() {
        let h = Harness()
        h.press(id: 4)
        h.press(id: 5)
        #expect(h.repeatEngine.heldID == 5)
        // The first run's pending tick was cancelled — one
        // active hold at a time.
        #expect(h.cancels == 1)
        // The old release arriving later is stale and ignored.
        h.repeatEngine.released(id: 4)
        #expect(h.repeatEngine.heldID == 5)
    }

    @Test("Teardown cancels — no release can arrive")
    func teardownCancels() throws {
        let h = Harness()
        h.press(id: 6)
        h.repeatEngine.cancelRun()
        #expect(h.repeatEngine.heldID == nil)
        #expect(h.cancels == 1)
        // A cancelled run's work firing late is inert.
        let lateTick = h.ticks.popLast()
        try #require(lateTick).work()
        #expect(h.fired.isEmpty)
    }

    @Test("A run that outlives its bound is force-ended")
    func overrunForceEndsTheRun() throws {
        // The stop signal is one Carbon release event; a lost
        // one must cost a bounded hold, never the session
        // (#611's force-settle shape). The bound is derived
        // from the constant, never restated.
        let h = Harness()
        h.press(id: 8)
        var spent: TimeInterval = 0.5
        var ticks = 0
        while h.repeatEngine.heldID != nil {
            try h.runTick(id: 8)
            if let next = h.ticks.last?.delay {
                spent += next
            }
            ticks += 1
            try #require(ticks < 100_000)
        }
        #expect(h.overruns == 1)
        #expect(h.ticks.isEmpty)
        #expect(spent >= HoldRepeat.maxRunSeconds)
        // The rescue is one recovery shape: a fresh press arms
        // a fresh run.
        h.press(id: 9)
        #expect(h.repeatEngine.heldID == 9)
    }

    @Test("A nested fire's tally never leaks into the outer's")
    func nestedFireTallyIsIsolated() {
        // A Lua body that pumps a run loop can deliver a second
        // press mid-fire (the case `KeybindingManager.fire`'s
        // `wasFiring` exists for). The inner fire judges its own
        // tally; the outer fire's counts come back via the
        // snapshot and are judged on their own.
        let h = Harness()
        _ = h.repeatEngine.beginFire()
        h.repeatEngine.noteCommand("resize", succeeded: true)

        // Nested press: one successful resize — arms id 2.
        let saved = h.repeatEngine.beginFire()
        h.repeatEngine.noteCommand("resize", succeeded: true)
        h.repeatEngine.endFire(id: 2, press: true)
        #expect(h.repeatEngine.heldID == 2)
        h.repeatEngine.restoreTally(saved)

        // The outer fire runs a second command and closes: two
        // commands total, so it must not arm — and had the
        // snapshot leaked, the inner's lone resize would have
        // made it look like one.
        h.repeatEngine.noteCommand("focus", succeeded: true)
        h.repeatEngine.endFire(id: 1, press: true)
        #expect(h.repeatEngine.heldID == nil)
    }
}
