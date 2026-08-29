import Foundation
import Testing

@testable import KiwiDeskCore

/// The shared machine harness for the hold-to-glide ladder
/// (#1056/#1082): every seam captured, nothing live. Its own file
/// because two suites drive it — `HoldGlideTests` (arming,
/// eligibility, teardown) and `HoldGlideRunTests` (the glide
/// itself) — split at §2.1's ceiling rather than after crossing
/// it.
///
/// `ticks` holds each scheduled (delay, work) pair — only ever
/// the ONE pre-glide wait, since the glide rides frames — `steps`
/// each glide step as (args, scale), and the initial delay is a
/// constant so no test reads the host's key-repeat preferences.
@MainActor
final class HoldGlideHarness {
    let repeatEngine = HoldGlide()
    var ticks: [(delay: TimeInterval, work: () -> Void)] = []
    var cancels = 0
    var steps: [(command: String, args: [JSONValue], scale: Double)] = []
    /// How many times the glide-end seam fired — the #674 arm's
    /// "pay it once at the end" contract.
    var glideEnds = 0
    var overruns = 0
    var frameStops = 0
    /// What `applyGlideStep` reports back — false is a resize
    /// that started failing mid-hold.
    var applySucceeds = true
    /// The live frame callback, once the glide has begun.
    private var frameTick: ((TimeInterval) -> Void)?

    init(releaseCapable: Bool = true) {
        repeatEngine.releaseCapable = releaseCapable
        repeatEngine.initialDelay = { 0.5 }
        repeatEngine.schedule = { [weak self] delay, work in
            self?.ticks.append((delay, work))
            return { self?.cancels += 1 }
        }
        repeatEngine.startFrames = { [weak self] tick in
            self?.frameTick = tick
            return {
                self?.frameStops += 1
                self?.frameTick = nil
            }
        }
        repeatEngine.applyGlideStep = {
            [weak self] command, args, scale in
            self?.steps.append((command, args, scale))
            return self?.applySucceeds ?? false
        }
        repeatEngine.onGlideEnd = { [weak self] in
            self?.glideEnds += 1
        }
        repeatEngine.onOverrun = { [weak self] in
            self?.overruns += 1
        }
    }

    /// One press-fire that ran exactly the given commands.
    func press(
        id: UInt32,
        commands: [(String, Bool)] = [("resize", true)],
        args: [JSONValue] = [.string("x"), .number(50)]
    ) {
        _ = repeatEngine.beginFire()
        for (name, ok) in commands {
            repeatEngine.noteCommand(
                name,
                args: args,
                succeeded: ok
            )
        }
        repeatEngine.endFire(id: id)
    }

    /// Fires the pending pre-glide wait, which starts the
    /// frame clock. The `#require` is load-bearing
    /// (guard-prover, #1056): a regression that stops
    /// scheduling must fail the TEST, not trap the whole
    /// runner on an empty array.
    func beginGlide() throws {
        let popped = ticks.popLast()
        try #require(popped).work()
    }

    /// One display frame.
    func frame(_ dt: TimeInterval = 1.0 / 60) throws {
        // Bound before calling: `#require(x)(y)` crashes
        // the 6.x type checker (ConstraintSystem assertion).
        let tick = try #require(frameTick)
        tick(dt)
    }

    var isTicking: Bool { frameTick != nil }
}
