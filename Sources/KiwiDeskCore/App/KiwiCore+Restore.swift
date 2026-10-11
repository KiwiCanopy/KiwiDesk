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
                // may assign none, on another display — beside a
                // hand float a stop carried (#1864).
                missing += 1
                let floating = record.floating == true
                if !corner || floating,
                    state.rememberedSpaces[record.windowID] != nil
                {
                    state.restoredFrames[record.windowID] = .init(
                        frame: record.frame,
                        floating: floating
                    )
                }
                continue
            }
            // A parked float's record is the capture the old
            // process held (#1352): SEED it, never set it — a set
            // lands on a window the forced park that follows
            // overwrites, and the seed door outranks the boot
            // retile's centred seed. A float the quit gathered off
            // a hidden Space takes it too (#1864).
            let float = restoresAsFloat(record.windowID)
            // A corner record carries no original; a window not at a
            // corner stands where its app or a pass left it, on every
            // replay leg (#2130).
            if float, corner, !tiler.looksStashed(current),
                let space = state.workspaces.space(of: record.windowID),
                seedWithoutOriginal(record.windowID, in: space)
            {
                continue
            }
            let parks = float && (corner || parksNow(record.windowID))
            if tiler.looksStashed(current) || parks {
                if !corner {
                    tiler.seedStash(
                        record.windowID,
                        frame: record.frame
                    )
                }
                continue
            }
            // Seeded beside the set (#1864): the activation below
            // may park it before the set's echo lands, and the park
            // would keep the quit grid's frame as its original.
            if float {
                tiler.seedStash(record.windowID, frame: record.frame)
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

    /// Whether a replayed window is an effective float in the Space
    /// the replay filed it in: no layout places it, so its record
    /// is the frame it returns to.
    private func restoresAsFloat(_ id: WindowID) -> Bool {
        let space = state.workspaces.space(of: id)
        return EffectiveFloat.applies(
            isFloating: state.windows[id]?.isFloating == true,
            mode: space.flatMap { state.workspaces[$0]?.mode }
        )
    }

    /// Whether the pass after the replay parks `id`: filed in a
    /// Space no display shows, under the stash's own verdict.
    private func parksNow(_ id: WindowID) -> Bool {
        guard let space = state.workspaces.space(of: id),
            let window = state.windows[id]
        else { return false }
        return !state.workspaces.visibleSpaces.contains(space)
            && state.parksOnInactive(window, in: space)
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
        // A corner rides the debt only for its float (#1352).
        guard let frame = effects.restoredFrame,
            !tiler.looksStashed(frame)
        else { return }
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
        crash.restoreKeys.boot(self)
        // A file the id gates refused is matched by its stable
        // keys instead — never over this session's own (#1385).
        let refused = crash.takeCrossSessionCandidate()
        guard let session = session ?? refused.flatMap(armCrossSessionMatch)
        else {
            retile()
            return
        }
        let signposter = BootSignpost.signposter
        let span = signposter.beginInterval("sessionRestore")
        // Held Spaces first, so the replay files into them (#1646).
        let holds = restoreHeldSpaces(from: session)
        // The temporary ones too, on the same ground (#1790).
        restoreTemporarySpaces(from: holds.snapshot)
        // Placed ahead of the activation below, which reads it.
        placeUnplacedSpaces()
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
