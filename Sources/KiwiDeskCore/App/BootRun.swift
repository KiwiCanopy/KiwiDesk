import Foundation
import os

/// In-flight boot phase state, timestamps, and readiness latch (#801).
@MainActor
final class BootRun {
    /// Handler fired on boot phase transition (`AppDelegate`).
    var onPhaseChange: @MainActor (BootPhase) -> Void = { _ in }

    private(set) var phase: BootPhase = .idle

    /// Latch indicating whether this launch finished booting — a
    /// LATCH, not a reading of `phase`: `stop()` publishes
    /// `.idle`, so a second stop (quit after a mid-boot permission
    /// revoke) would look "not starting" and write the fraction of
    /// a desk the interrupted scan collected over the preserved
    /// session (code review 2026-08-12).
    var reachedReady = false

    /// Signpost interval state for boot duration reporting (#672).
    var interval: OSSignpostIntervalState?
    var began: ContinuousClock.Instant?
    var configDone: ContinuousClock.Instant?
    var scanDone: ContinuousClock.Instant?

    /// Publishes next boot phase if changed.
    func publish(_ next: BootPhase) {
        guard next != phase else { return }
        phase = next
        onPhaseChange(next)
    }
}
