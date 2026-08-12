import Foundation
import os

/// The in-flight boot's phase, spans and timestamps (#801).
///
/// A holder type rather than four more stored properties on
/// `KiwiCore`: the boot no longer runs inside one `start()` call,
/// so the interval states and phase timestamps have to outlive
/// the call that opened them, and `KiwiCore.swift` sits within a
/// few lines of the §2.1 ceiling.
///
/// `publish` is the one write path — it drops an unchanged phase,
/// so a chunk that attaches nothing still costs the GUI nothing.
@MainActor
final class BootRun {
    /// Fired on every phase change, including back to `.idle` on
    /// a permission revoke, so a readiness signal clears itself.
    /// Wired by the GUI (`AppDelegate`); defaults to a no-op
    /// because a headless core (the CLI, a test) has no signal to
    /// draw.
    var onPhaseChange: @MainActor (BootPhase) -> Void = { _ in }

    private(set) var phase: BootPhase = .idle

    /// The `boot` signpost interval, open from the prologue until
    /// the tail — one interval across the chunks, so Instruments
    /// still shows a single boot span (#672's contract).
    var interval: OSSignpostIntervalState?
    /// When `start()` began, and when config and scan finished —
    /// the three durations the boot summary line reports.
    var began: ContinuousClock.Instant?
    var configDone: ContinuousClock.Instant?
    var scanDone: ContinuousClock.Instant?

    func publish(_ next: BootPhase) {
        guard next != phase else { return }
        phase = next
        onPhaseChange(next)
    }
}
