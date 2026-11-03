import Foundation

/// The per-app queues every frame and EUI hold rides, split from
/// `FrameApplier.swift` (350-line ceiling).
extension FrameApplier {
    func queue(for pid: pid_t) -> DispatchQueue {
        // Own process runs on main queue to prevent AppKit thread traps
        // (#678 Phase 5).
        if pid == getpid() {
            return DispatchQueue.main
        }
        if let existing = queues[pid] {
            return existing
        }
        let queue = DispatchQueue(
            label: "org.kiwidesk.frames.\(pid)",
            qos: .userInteractive
        )
        queues[pid] = queue
        return queue
    }

    /// EUI holds ride the same per-app queue as the frames, so
    /// off → frames → on ordering is guaranteed.
    func holdEUI(pid: pid_t, held: Bool) {
        let holds = enhancedUI
        let writer = writer
        if held {
            holds.noteQueued(
                pid,
                atRest: enhancedUIAtRest(pid),
                instant: false
            )
        }
        queue(for: pid).async {
            if held {
                holds.acquire(pid, writer)
            } else {
                holds.release(pid, writer)
            }
        }
    }

    /// The event loop stopped owning the app and left its EUI
    /// at `leftOn`; a hold still open restores that.
    func retireApp(_ pid: pid_t, leftOn: Bool) {
        enhancedUI.retire(pid, leftOn: leftOn)
    }
}
