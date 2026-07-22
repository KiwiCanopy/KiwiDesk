import Foundation

/// Snapshot restore: replays saved state after wake/unlock, a
/// crash, or a restart. Split from `KiwiCore+Events.swift` (event
/// flow) for file size (§2) — the two share the extension but not
/// the concern.
extension KiwiCore {
    /// Re-applies a snapshot after wake/unlock, a crash, or a
    /// restart: space membership and order first (the array
    /// order is the layout order), then the raw frames. Frames
    /// go through the tiler's frame pipeline so the resulting
    /// AX echoes are not mistaken for user drags.
    func restore(_ snapshot: StateSnapshot) {
        state.adopt(snapshot)
        for record in snapshot.windows {
            tiler.setFrame(record.windowID, record.frame)
        }
        // Diagnostic: snapshot windows that are not tracked
        // yet stay out of their space until a reconcile finds
        // them (cold-AX startup scan, issue #21 follow-up).
        let missing = snapshot.windows.filter {
            state.windows[$0.windowID] == nil
        }.count
        if missing > 0 {
            onLog(
                "restore: \(missing) snapshot windows not "
                    + "tracked yet"
            )
        }
    }
}
