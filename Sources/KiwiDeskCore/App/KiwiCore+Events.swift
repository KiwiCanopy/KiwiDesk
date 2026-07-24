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
            // tracks the ring (#285), so an AX echo can't rewind it
            // behind the live bounds — the guard lives there, once.
            borders.follow(id, windowFrame: frame)
            stickyIndicators.follow(id, windowFrame: frame)
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
            borders.follow(id, windowFrame: frame)
            stickyIndicators.follow(id, windowFrame: frame)
            // Same policy as .windowMoved above: a genuine
            // user resize takes the window over.
            if !tiler.didRecentlySetFrame(id),
                !TilingEngine.looksStashed(frame)
            {
                tiler.forgetStash(id)
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
            // Ring only: a native-fullscreen window fills the
            // display, so a ring would show only at the corners —
            // drop it now, restore it when fullscreen ends. The
            // state fold already flipped the snapshot flag; no
            // retile (the window keeps its home-space slot).
            updateBorders()
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
            cancelDrag(old)
        default:
            break
        }
        let willRetile = TilingEngine.shouldRetile(after: event)
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
            eventLoop.isListed(next)
        {
            focusWindow(next, warp: true)
        }
        // A structural change in a track space (spawn, close) can
        // push a window into an overflow cascade; fix the pile's
        // z-order once it settles (#193, self-gated on track +
        // actual overflow). AFTER the focus fallback above, so the
        // restore's closing re-focus targets the settled focus,
        // never a stale/nil one (which would clear focus on a
        // minimize).
        if TilingEngine.shouldRetile(after: event) {
            scheduleTrackZOrderRestoreIfOverflowing()
        }
    }
}
