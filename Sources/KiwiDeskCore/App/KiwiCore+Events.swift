import AppKit
import Foundation

/// The event flow: every `KiwiEvent` from the AX event loop
/// routes through `handle` — state first, then per-event side
/// effects, then the structural retile — plus the snapshot
/// restore that replays state after wake/unlock or a crash.
/// Split from `KiwiCore.swift` (wiring) for file size (§2).
extension KiwiCore {
    func handle(_ event: KiwiEvent) {
        // `state.apply` folds the event in and hands back the
        // facts the write erases — the gone window's app / space /
        // focus, the pre-echo focus, a float flip, and the appear
        // facts (#166). handle() only composes the clock/AX-aware
        // side effects on top; the pure classifiers stay below.
        state.spawnPlacements = [
            .bsp: tiler.settings.bsp.newWindowPlacement,
            .stack: tiler.settings.stack.newWindowPlacement,
            .scrolling:
                tiler.settings.scrolling.newWindowPlacement,
            .grid: tiler.settings.grid.newWindowPlacement,
            .monocle: tiler.settings.monocle.newWindowPlacement,
        ]
        state.spawnOverride = tiler.settings.placementOverride
        state.trackParams = tiler.settings.track
        // Fill-then-spill needs each track space's capacity (#437),
        // which is display geometry — resolve it here and mirror it
        // in like `trackParams`, so a `focused_track` spawn reads a
        // plain Int and the state core stays geometry-free. Only a
        // window creation consumes it, so skip the per-space context
        // builds on every other (higher-frequency) event.
        if case .windowCreated = event {
            state.trackCapacities = tiler.trackCapacities(
                state: state
            )
        }
        let effects = state.apply(event)
        var newlyCreatedWindow: WindowID? = nil
        switch event {
        case .displaysChanged:
            tiler.displaysChanged()
            borders.displaysChanged()
            handleMonitorChange()
            emitMonitorChange()
        case .windowFocused(let id):
            handleWindowFocused(id, effects: effects)
        case .windowCreated(let window):
            // A brand-new window supersedes a pending follow
            // of a hidden window (see above).
            deferred.cancel(.focusFollow)
            newlyCreatedWindow = window.id
            emitWindowCreated(
                window,
                reason: WindowAppearReason.classify(
                    wasMinimized: effects.appearedWasMinimized,
                    hadRememberedSpace: effects.hadRememberedSpace
                )
            )
        case .windowMoved(let id, let frame):
            // Keep the ring glued to a window being moved. `follow`
            // self-suppresses when the WindowServer stream already
            // tracks the ring (#285) and while our own animation
            // drives the window (#594), so a laggy AX echo can't
            // rewind it — the guards live there, once. No size
            // pin: an echo IS reality (#677).
            borders.follow(
                id,
                windowFrame: frame,
                source: .axEcho,
                pin: nil
            )
            stickyMarks.follow(
                id,
                windowFrame: frame,
                source: .axEcho,
                pin: nil
            )
            // A genuine user move (not the echo of our own
            // frame-set) supersedes a pending stash restore:
            // the user took the window over, so the captured
            // frame no longer says where it belongs (#412).
            // A frame AT a stash corner is treated as an echo
            // even past the applier's grace — a stalled app's
            // late stash echo must not strand the window there.
            if !tiler.didRecentlySetFrame(id),
                !TilingEngine.looksStashed(frame)
            {
                tiler.forgetStash(id)
            }
            drag.windowMoved(id, frame: frame)
        case .windowResized(let id, let frame):
            borders.follow(
                id,
                windowFrame: frame,
                source: .axEcho,
                pin: nil
            )
            stickyMarks.follow(
                id,
                windowFrame: frame,
                source: .axEcho,
                pin: nil
            )
            // Same policy as .windowMoved above: a genuine
            // user resize takes the window over.
            if !tiler.didRecentlySetFrame(id),
                !TilingEngine.looksStashed(frame)
            {
                tiler.forgetStash(id)
            }
            // A genuine resize also stales the learned size
            // bound (#677): the user or the app itself changed
            // the size — System Settings switching panes moves
            // its fixed width — so the next retile must probe
            // fresh rather than skip on a dead answer.
            if !tiler.didRecentlySetFrame(id) {
                tiler.forgetSizeBound(id)
            }
            // Resize gestures share the drag pipeline (same
            // settle debounce). Only mouse-driven resizes
            // count; apps resizing themselves are corrected
            // by the next retile. `validated` lets the
            // trailing events of a fast resize (classified
            // via the recent press near a slot edge) start
            // the gesture even after the release.
            if isResizeGesture(id) {
                drag.windowMoved(
                    id,
                    frame: frame,
                    validated: true
                )
            }
        case .windowDestroyed(let id, let wasMinimized):
            // Drop any unechoed self-raise for the gone window: its
            // echo will never land, and WindowIDs can be reused
            // (#152/#158). Same for a pending z-order-raise echo.
            outstandingSelfRaises.remove(id)
            zOrderRaiseEchoes[id] = nil
            // WindowIDs are reused (#152/#158): a bound learned
            // for the gone window must not skip the next one.
            tiler.forgetSizeBound(id)
            cancelDrag(id)
            dragOverlay.hideAll()
            // The switch timestamp is set by the
            // .nativeSpaceChanged event, which the event loop
            // emits BEFORE the reconcile burst on the same
            // run-loop turn — so vanish classification is
            // ordering, not a race (#40).
            let reason = WindowGoneReason.classify(
                wasMinimized: wasMinimized,
                sinceNativeSwitch: Date()
                    .timeIntervalSince(lastNativeSwitch)
            )
            emitWindowDestroyed(
                id,
                app: effects.removedWindow?.app,
                bundleID: effects.removedWindow?.bundleID,
                space: effects.removedWindow?.space,
                reason: reason
            )
        case .windowTitleChanged:
            if effects.floatFlipped {
                retile()
            }
        case .windowFullscreenChanged:
            // The state fold already flipped the snapshot flag;
            // the generic `shouldRetile` retile re-partitions
            // the layout around it (#670: entering fullscreen
            // exempts the slot, leaving re-places it) and that
            // retile refreshes the bars and the ring (fills the
            // display, so a ring would show only at the
            // corners — drop it now, restore on exit).
            break
        case .nativeSpaceChanged:
            handleNativeSpaceChange()
        case .windowRekeyed(let old, let new):
            // A native-tab active-tab change: the state fold already
            // moved the slot's id (position, focus, weights). The OS
            // made the new tab frontmost itself, so we must NOT raise
            // — that is the focus jump we are fixing. Retarget our own
            // id-keyed bookkeeping; the retile below refreshes the
            // ring, App Bar, and frames onto the new id (#308).
            if outstandingSelfRaises.remove(old) != nil {
                outstandingSelfRaises.insert(new)
            }
            if let stamp = selfRaiseStamps.removeValue(
                forKey: old
            ) {
                selfRaiseStamps[new] = stamp
            }
            if let stamp = zOrderRaiseEchoes.removeValue(forKey: old) {
                zOrderRaiseEchoes[new] = stamp
            }
            if pendingFocusRaise == old {
                pendingFocusRaise = new
            }
            // The move-intent latch is id-keyed bookkeeping too
            // (#482): its window may still hold OS key focus, so
            // its re-report can arrive under the fresh id.
            moveLatch.rekey(old: old, new: new)
            // A stashed floating window's captured frame must
            // follow the re-key too, or the restore sweep drops
            // it and the window stays parked at the stash
            // corner forever — #412's "floating vanishes"
            // failure mode, reintroduced on this one path.
            tiler.rekeyStash(oldID: old, newID: new)
            // The learned size bound follows the id swap too
            // (#677): same on-screen window, same app-side
            // constraint, new id.
            tiler.rekeySizeBound(oldID: old, newID: new)
            // A live display crossing's bookkeeping (#504) must
            // follow the id swap, or a rekey after a crossing
            // strands the (new) window on the destination space
            // with no record to revert from. Transfer FIRST —
            // cancelDrag(old) then finds nothing under the old
            // id — and revert under the new one: the gesture is
            // aborted, so the window goes home like any other
            // abnormal end.
            dragCrossing.rekey(old: old, new: new)
            cancelDrag(old)
            revertLiveCrossing(new)
        default:
            break
        }
        let willRetile =
            TilingEngine.shouldRetile(after: event)
            && !defersEventRetiles
        if willRetile {
            retile(newlyCreatedWindow: newlyCreatedWindow)
        }
        // Closing or minimizing the focused window hands focus
        // to the space's fallback (state picked one; this raise
        // makes it real). Only raise windows the app still lists:
        // after a native Space switch the fallback may live on
        // the previous desktop, and raising it would switch back.
        if effects.removedWindow?.focusLost == true,
            let next = activeSpace?.focused,
            eventLoop.isListed(next),
            // Belt to the fold's re-pick (#670): never raise a
            // fullscreen fallback — it would switch the user
            // to its Space on a plain window close.
            state.windows[next]?.isFullscreen != true
        {
            focusWindow(next, warp: true)
            armCloseReturnRestack(
                to: next,
                fromRemovedSlot: effects.removedWindow?.tiledSlot
            )
        }
        // A structural change in a track space (spawn, close) can
        // push a window into an overflow cascade; fix the pile's
        // z-order once it settles (#193, self-gated on track +
        // actual overflow). AFTER the focus fallback above, so the
        // restore's closing re-focus targets the settled focus,
        // never a stale/nil one (which would clear focus on a
        // minimize).
        if willRetile {
            scheduleTrackZOrderRestoreIfOverflowing()
        }
    }

    /// #674, the close path: a close-return pick can cross
    /// several scrolling slots, and `focusWindow`'s own jump arm
    /// cannot see it — the destroy fold already wrote the pick
    /// into `space.focused`, so the anchor the jump test
    /// classifies from IS the target (distance zero), and the
    /// closed window has left the row besides. Re-derive the
    /// distance from the REMOVED slot instead: the old focus sat
    /// there, and the successor pick inherits it, which is why
    /// the close path never jumped before close-return existed.
    /// The same anchor blindness means the #143 backward-pan
    /// deferral can never defer this raise; that stays the
    /// close-handoff's documented immediate-raise behavior
    /// (`focusWindow`'s own comment), a pop being cheaper than a
    /// spurious deferral on every close. Self-gated downstream on
    /// scrolling + actual overflow; a nil slot (the closed window
    /// was a float or fullscreen member) or a candidate outside
    /// the tiled row is no evidence of a jump — same asymmetry
    /// as `scrollFocusJumpsSlots`. Internal, not private: the
    /// call site above sits behind `eventLoop.isListed` (live
    /// AX — the `TransientOverlayFocusTests` gate note), so
    /// `ZOrderCloseReturnArmTests` proves the arm directly.
    func armCloseReturnRestack(
        to target: WindowID,
        fromRemovedSlot slot: Int?
    ) {
        guard let slot, let space = activeSpace else { return }
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: space.id
        )
        guard !tiled.isEmpty,
            let targetIndex = tiled.firstIndex(of: target)
        else { return }
        let from = min(slot, tiled.count - 1)
        if abs(targetIndex - from) > 1 {
            scheduleScrollingZOrderRestoreIfOverflowing()
        }
    }
}
