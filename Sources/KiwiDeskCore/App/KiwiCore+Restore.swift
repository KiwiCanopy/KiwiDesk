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
        // A replay is not an entry (#1177): the frames it puts
        // back are the user's, and the entry it re-states was
        // gathered when it happened.
        settleDrawnSpaceModes()
        state.adopt(snapshot)
        state.restoredFrames = [:]
        var missing = 0
        for record in snapshot.windows {
            // A record that is itself a corner is no original
            // and is left alone on both arms (#1352).
            let corner = tiler.looksStashed(record.frame)
            guard let current = state.windows[record.windowID]?.frame
            else {
                // Not tracked yet (a slow app's window, #21):
                // `adopt` filed its Space, and its frame is owed
                // at its arrival (#1362) — the space it lands in
                // may assign none, on another display.
                missing += 1
                if !corner,
                    state.rememberedSpaces[record.windowID] != nil
                {
                    state.restoredFrames[record.windowID] =
                        record.frame
                }
                continue
            }
            // A parked float's record is the capture the old
            // process held (#1352): SEED it, never set it — a set
            // lands on a window the forced park that follows
            // overwrites, and the seed door outranks the boot
            // retile's centred seed.
            if tiler.looksStashed(current) {
                if !corner {
                    tiler.seedStash(
                        record.windowID,
                        frame: record.frame
                    )
                }
                continue
            }
            tiler.setFrame(record.windowID, record.frame)
        }
        if missing > 0 {
            onLog(
                "restore: \(missing) snapshot windows not "
                    + "tracked yet; \(state.restoredFrames.count) "
                    + "frame(s) owed at arrival"
            )
        }
    }

    /// Pays a restored frame the arrival fold handed back
    /// (#1362): seeded, never set, so the arrival retile's own
    /// restore pass delivers it on a shown space and the park
    /// keeps it for the activation on an unshown one — the
    /// #1352 door, which a layout frame outranks where the
    /// space assigns one.
    func payRestoredFrame(
        arrived window: WindowID,
        effects: AppliedEffects
    ) {
        guard let frame = effects.restoredFrame else { return }
        tiler.seedStash(window, frame: frame)
        onLog(
            "restore: w\(window.raw) arrived late — its snapshot "
                + "frame is seeded for delivery"
        )
    }

    /// The crash leg's restore contract: replay, then settle
    /// like any other space switch — force past the ±2 pt
    /// tolerance and tell bus subscribers (the bar) where we
    /// landed (#633). No focus seeding on purpose: it runs
    /// inside `start()`, whose startup sweep re-runs the
    /// landing choice and `seedStartupFocus`. The launch-time
    /// session restore seeds focus itself (`KiwiCore+Lifecycle`)
    /// and the wake/unlock leg pays the adopted focus for real
    /// (`restoreAndSettleAfterWake`, #1130).
    func restoreAndSettle(_ snapshot: StateSnapshot) {
        restore(snapshot)
        spaceSwitchRetile()
        emitSpaceChange()
    }
}
