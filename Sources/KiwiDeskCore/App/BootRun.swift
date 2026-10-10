import Foundation
import os

/// In-flight boot phase state, timestamps, and readiness latch (#801).
@MainActor
final class BootRun {
    /// Handler fired on boot phase transition (`AppDelegate`).
    var onPhaseChange: @MainActor (BootPhase) -> Void = { _ in }

    private(set) var phase: BootPhase = .idle

    /// Latch indicating whether this launch finished booting.
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

    /// Handler fired on restore progress (#2133, `AppDelegate`).
    var onRestoreChange: @MainActor (RestorePhase) -> Void = { _ in }

    private(set) var restore: RestorePhase = .none

    /// Publishes the restore's progress if changed.
    func publishRestore(_ next: RestorePhase) {
        guard next != restore else { return }
        restore = next
        onRestoreChange(next)
    }
}
