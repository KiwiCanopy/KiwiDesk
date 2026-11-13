import ApplicationServices
import Foundation

/// The instant set's queue half: one block per set inside the
/// batched EUI hold (#1508), or, latest-wins, at most one block
/// per window waiting, which writes the newest frame when it runs
/// (#3266).
extension FrameApplier {
    /// Queues `entry` on the app's queue. A latest-wins set merges
    /// into a block already waiting for the window and is counted
    /// as coalesced; every other write retired a waiting one at
    /// its entry point, `apply` or `applyInstant`.
    func enqueueInstant(
        _ id: WindowID,
        _ entry: PendingFrames.Entry,
        pid: pid_t,
        latestWins: Bool
    ) {
        if latestWins, latestInstants.put(id, entry) {
            meter.add(\.framesCoalesced)
            return
        }
        nonisolated(unsafe) let entry = entry
        let store = latestInstants
        let stamp = recentStamp
        let writer = writer
        let holds = enhancedUI
        let waited = meter.queued()
        holds.noteQueued(
            pid,
            atRest: enhancedUIAtRest(pid),
            instant: true
        )
        queue(for: pid).async {
            waited()
            holds.beginInstant(pid, writer)
            if let write = latestWins ? store.take(id) : entry {
                Self.write(write, writer)
            }
            holds.endInstant(pid, writer)
            stamp(id)  // as `apply`, #1254
        }
    }

    /// One instant set's AX calls, on the app's queue.
    nonisolated private static func write(
        _ entry: PendingFrames.Entry,
        _ writer: FrameWriter
    ) {
        if let lead = entry.lead {
            lead.write(entry, writer)
        } else if entry.setSize {
            EdgeBandWrite.write(
                entry.frame,
                entry.element,
                nearEdgeOf: entry.band,
                writer: writer
            )
        } else {
            writer.setPosition(entry.frame.origin, entry.element)
        }
    }
}
