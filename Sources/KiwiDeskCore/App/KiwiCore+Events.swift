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
        let effects = state.apply(event)
        var newlyCreatedWindow: WindowID? = nil
        switch event {
        case .displaysChanged:
            tiler.displaysChanged()
            handleMonitorChange()
            emitMonitorChange()
        case .windowFocused(let id):
            // Dismissing an ignored panel (Ghostty's quick
            // terminal) leaves the app frontmost and makes AX
            // re-report its managed main window — which may live
            // on another space — as focused. Following that
            // stale report switches spaces, or in a focus-driven
            // layout yanks focus to the main window on the
            // active space. The panel was flagged active while
            // it held focus (#21); consume the flag here and
            // restore the pre-panel focus instead of acting on
            // the report (#244). A focus landing on any other
            // app means the panel's app resigned frontmost, so
            // drop stale flags to keep a later genuine focus of
            // that app from being suppressed.
            if let pid = state.windows[id]?.pid {
                if ignoredPanelActive.remove(pid) != nil {
                    // The report is spurious, but the id could
                    // still be an outstanding self-raise; drop
                    // it so a later genuine focus of this window
                    // is not misread as our own echo (cf. the
                    // .windowDestroyed cleanup below).
                    outstandingSelfRaises.remove(id)
                    if let before = effects.focusBefore,
                        let space = state.workspaces.space(
                            of: before
                        )
                    {
                        state.workspaces.focus(
                            before,
                            in: space
                        )
                    }
                    return
                }
                ignoredPanelActive.removeAll()
            }
            // Echo provenance (#152/#158): an echo of KiwiDesk's
            // own AX raise is not a user action. When one lands
            // after focus has already moved on in the active
            // scrolling space — a later raise, deferred or
            // forward-immediate — the echo (and the state focus
            // StateCoordinator just moved onto the echoed window)
            // would revert to the stale target. Re-assert the
            // intended focus and drop the echo. Consume the id
            // from the outstanding set either way.
            let selfEcho = outstandingSelfRaises.remove(id) != nil
            if selfEcho,
                activeSpace?.mode.defersFocusRaise == true,
                let intended = effects.focusBefore, intended != id,
                state.workspaces.space(of: id)
                    == state.workspaces.activeSpace
            {
                if let space = state.workspaces.space(
                    of: intended
                ) {
                    state.workspaces.focus(intended, in: space)
                }
                return
            }
            // A real focus echo (a user click mid-pan) or a self
            // echo that matches the intended focus supersedes the
            // deferred raise (#143): the OS already raised whatever
            // the user reached, and a stale raise firing after the
            // pan would steal focus back.
            pendingFocusRaise = nil
            emitFocusChange(id)
            // Move the focus ring to the newly focused window.
            // Static layouts don't retile on focus (below), so
            // this is the only refresh they get; focus-driven
            // layouts retile and refresh again (cheap, idempotent).
            updateBorders()
            // Warp only for focus changes KiwiDesk did not
            // make itself (cmd+tab, app-driven focus): a
            // self-raise already warped at intent time in
            // `focusWindow`, and an echo that moved no focus
            // (same-window re-focus) is not a change (#186).
            if !selfEcho, effects.focusBefore != id {
                warpMouseToFocused(id)
            }
            // cmd+tab (or a click) can reach a window hidden
            // in an inactive virtual space; pull that space
            // forward instead of typing into a stashed window.
            // Deferred: app activation transiently re-reports
            // the app's OLD focused window right before a new
            // window opens — only follow if focus settles.
            if let space = state.workspaces.space(of: id),
                space != state.workspaces.activeSpace
            {
                scheduleFocusFollow(id)
            } else if activeSpace?.mode.isFocusDriven == true {
                retileWithScrollDuration()
            }
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
            drag.windowMoved(id, frame: frame)
        case .windowResized(let id, let frame):
            borders.follow(id, windowFrame: frame)
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
            // (#152/#158).
            outstandingSelfRaises.remove(id)
            drag.cancel(id)
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
                space: effects.removedWindow?.space,
                reason: reason
            )
        case .windowTitleChanged:
            if effects.floatFlipped {
                retile()
            }
        case .nativeSpaceChanged:
            handleNativeSpaceChange()
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
