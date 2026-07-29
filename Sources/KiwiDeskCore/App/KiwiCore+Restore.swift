import Foundation

/// Snapshot restore: replays saved state after wake/unlock, a
/// crash, or a restart. Split from `KiwiCore+Events.swift` (event
/// flow) for file size (§2) — the two share the extension but not
/// the concern.
extension KiwiCore {
    /// Re-applies a snapshot after wake/unlock, a crash, or a
    /// restart: layout modes first, then space membership and
    /// order (the array order is the layout order), then the
    /// raw frames. Frames go through the tiler's frame pipeline
    /// so the resulting AX echoes are not mistaken for user
    /// drags.
    func restore(_ snapshot: StateSnapshot) {
        // Modes before adopt, never after: a runtime `set_mode`
        // was captured but silently reverted on every restore
        // (#633) — and entering track mode seeds a default
        // partition, which `adopt` then replaces with the
        // snapshot's own breaks/weights (writing even an empty
        // pair for a track record, so a captured single track
        // is not left showing the seed). The reverse order
        // would wipe the restored partition with the seed.
        // Same existence gate as `adopt`: never a new space.
        for record in snapshot.spaces {
            let space = SpaceID(record.id)
            guard state.workspaces[space] != nil else {
                continue
            }
            setSpaceMode(space, record.mode)
        }
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

    /// The full restore contract for the wake/unlock and crash
    /// paths: replay, then settle like any other space switch —
    /// force past the ±2 pt tolerance and tell bus subscribers
    /// (the bar) where we landed. Both paths used to stop at
    /// the bare replay (#633), which left everything un-retiled
    /// with stale bars. The launch-time session restore keeps
    /// its own sequence in `KiwiCore+Lifecycle` — it seeds
    /// focus between the replay and the settle. Crash restore
    /// gets no focus seeding here on purpose: it runs inside
    /// `start()`, whose 1 s startup sweep
    /// (`scheduleStartupSweep`) re-runs the landing choice and
    /// `seedStartupFocus` — that sweep is the focus half of
    /// this path's contract.
    func restoreAndSettle(_ snapshot: StateSnapshot) {
        restore(snapshot)
        spaceSwitchRetile()
        emitSpaceChange()
    }
}
