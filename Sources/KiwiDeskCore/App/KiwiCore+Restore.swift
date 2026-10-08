import Foundation
import os

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
        // Same existence gate as `adopt`: never a new space (a
        // held one boot created first counts as existing, #1646).
        // Captured under another arrangement, a Space the live one
        // declares keeps the mode it declares: that record's mode
        // was another arrangement's Space of the same name (#1646).
        let foreign =
            snapshot.arrangement.map { $0 != liveArrangement } ?? false
        let declaredHere = foreign ? liveHome?.declared ?? [] : []
        for record in snapshot.spaces {
            let space = SpaceID(record.id)
            guard state.workspaces[space] != nil,
                !declaredHere.contains(space)
            else {
                continue
            }
            setSpaceMode(space, record.mode)
        }
        // A replay is not an entry (#1177): the frames it puts
        // back are the user's, and the entry it re-states was
        // gathered when it happened.
        settleDrawnSpaceModes()
        state.adopt(snapshot)
        // The Monocle hold an in-place restart carried (#930);
        // the read validates membership.
        for record in snapshot.spaces {
            if let held = record.session?.monocleShown {
                tiler.monocleShownMembers[SpaceID(record.id)] =
                    WindowID(held)
            }
        }
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

    /// Boot's first arrangement: the previous session's — a clean
    /// stop's or a crash's autosave — REPLAYED BEFORE any pass
    /// draws, so every scanned window is filed in its remembered
    /// Space and slot before a frame is issued (#930,
    /// accessibility.md). With no session, the scan's order is the
    /// arrangement.
    ///
    /// Settles like any other space switch — its layout frames
    /// forced past the tolerance check, the animation respected
    /// (#207), the bar told where we landed. Internal so a test
    /// drives the boot tail; `finishBoot` is not test-drivable.
    func arrangeBootDesk(session: StateSnapshot?) {
        RestoreKeyLog.boot(self)
        guard let session else {
            retile()
            return
        }
        let signposter = BootSignpost.signposter
        let span = signposter.beginInterval("sessionRestore")
        // Held Spaces first, so the replay files into them (#1646).
        let holds = restoreHeldSpaces(from: session)
        // The temporary ones too, on the same ground (#1790).
        restoreTemporarySpaces(from: holds.snapshot)
        restore(holds.snapshot)
        settleHeldSpacesAtBoot(holds)
        adoptCarriedPartitioning(from: session)
        activateSpaceOfFocusedWindow()
        seedStartupFocus()
        spaceSwitchRetile(asSwitch: false)
        emitSpaceChange()
        signposter.endInterval("sessionRestore", span)
        onLog("restored previous session arrangement")
    }
}
