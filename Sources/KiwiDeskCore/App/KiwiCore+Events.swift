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
        if case .windowCreated(let window) = event {
            state.trackCapacities = tiler.trackCapacities(
                state: state
            )
            // The screen the arriving window's frame physically
            // sits on (#1010), mirrored in like the capacities
            // above: the fold prefers the space THAT display
            // shows over the one the window remembered on
            // another screen, and resolving a frame to a screen
            // needs `NSScreen` plus the AX/AppKit y-flip —
            // neither of which the pure state core may read
            // (§2.6). `screen(containing:)` owns the flip.
            state.arrivalDisplay =
                TilingEngine.screen(
                    containing: window.frame
                )?.kiwiDisplay?.id
        }
        // Read BEFORE the fold below overwrites/removes them —
        // both helpers argue their consumer.
        let preEventFrame = preEventFrame(of: event)
        let goneWindowPID = goneWindowPID(of: event)
        let effects = state.apply(event)
        var newlyCreatedWindow: WindowID? = nil
        switch event {
        case .appTerminated:
            forgetTerminatedStickyReach(effects.terminatedWindows)
        case .displaysChanged:
            tiler.displaysChanged()
            borders.displaysChanged()
            handleMonitorChange()
            emitMonitorChange()
            // #1145: a replug births fresh Desktops (#889).
            refreshStickyReach()
        case .windowFocused(let id):
            handleWindowFocused(id, effects: effects)
        case .windowCreated(let window):
            // A brand-new window supersedes a pending follow
            // of a hidden window (see above).
            deferred.cancel(.focusFollow)
            newlyCreatedWindow = window.id
            // A flapped window's parked size bounds come back
            // BEFORE the arrival retile below (#1049), so the
            // re-add tiles straight to the learned answer
            // instead of re-running the whole dance.
            tiler.reviveSizeBound(window.id, pid: window.pid)
            emitWindowCreated(
                window,
                reason: WindowAppearReason.classify(
                    wasMinimized: effects.appearedWasMinimized,
                    hadRememberedSpace: effects.hadRememberedSpace
                )
            )
            // #1010: narrate the cross-screen arrival, the
            // one resolution a device trace cannot read off
            // the membership alone.
            if let rehomed = effects.rehomedToScreenSpace {
                onLog(
                    "arrival: w\(window.id.raw) came back on "
                        + "another screen — homed to space "
                        + "\(rehomed.raw)"
                )
            }
            // #1007: a follow sent this window to a Desktop
            // nobody was showing, and THIS is when it becomes
            // addressable again. After the re-home above, so the
            // space it activates is the one the arrival settled
            // on. A no-op unless this window is the one owed.
            payFollowedFocus(arrived: window.id)
            if state.windows[window.id]?.isSticky == true {
                refreshStickyReach()
            }
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
            // #677: a refused SIZE emits no resized event —
            // the size never changed — but the probe's
            // position sets still echo as moves, and a move
            // echo carries the full frame: observe it. No
            // forget half here — a genuine move says nothing
            // about size bounds.
            if tiler.askEchoLikely(id) {
                observeSizeAnswer(
                    id,
                    size: frame.size,
                    channel: .moveEcho
                )
                // Reality reported — state beats stamp (#881).
                tiler.clearInstantTarget(id)
            }
            drag.windowMoved(
                id,
                frame: frame,
                previous: preEventFrame
            )
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
            // #677: an echo of our own set is the app's ANSWER
            // to the last ask — observe it now rather than at
            // the next retile, and place the residue (the
            // re-pack, the centering) the moment a bound is
            // confirmed. The confirmation edge fires once per
            // learned entry, so this retile cannot loop on its
            // own echoes.
            if tiler.askEchoLikely(id) {
                observeSizeAnswer(
                    id,
                    size: frame.size,
                    channel: .resizeEcho
                )
                tiler.clearInstantTarget(id)  // as :104, #881
            } else if !tiler.ledgerExplainsResize(
                id,
                size: frame.size
            ) {
                // A genuine resize stales the learned bound:
                // the user or the app itself changed the size —
                // System Settings switching panes moves its
                // fixed width — so the next retile must probe
                // fresh rather than skip on a dead answer. A
                // size the ledger already predicted is exempt:
                // that is a LATE echo of our own ask (#618's
                // read queue can outlast the applier's grace),
                // and wiping on it erased the learning over and
                // over (device QA, 2026-08-18).
                if tiler.sizeBound(for: id) != nil {
                    onLog(
                        "size bound staled by a genuine "
                            + "resize of window \(id.raw)"
                    )
                }
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
                    validated: true,
                    previous: preEventFrame
                )
            }
        case .windowDestroyed(let id, let wasMinimized):
            forgetGoneWindow(id, pid: goneWindowPID)
            if !wasMinimized { stickyReach.forget(id) }
            // The switch timestamp is set by the
            // .desktopChanged event, which the event loop
            // emits BEFORE the reconcile burst on the same
            // run-loop turn — so vanish classification is
            // ordering, not a race (#40).
            let reason = WindowGoneReason.classify(
                wasMinimized: wasMinimized,
                sinceDesktopSwitch: Date()
                    .timeIntervalSince(lastDesktopSwitch)
            )
            emitWindowDestroyed(
                id,
                app: effects.removedWindow?.app,
                bundleID: effects.removedWindow?.bundleID,
                space: effects.removedWindow?.space,
                reason: reason
            )
        case .windowHidden(let id):
            // Same forgetting as a destroy — the id can be
            // reused whether the window closed or its app hid.
            forgetGoneWindow(id, pid: goneWindowPID)
            // `.hidden` rather than the timing classifier: a
            // hide is explicit, like a minimize, so there is
            // nothing to infer from how long ago the desktop
            // switched (#913).
            emitWindowDestroyed(
                id,
                app: effects.removedWindow?.app,
                bundleID: effects.removedWindow?.bundleID,
                space: effects.removedWindow?.space,
                reason: .hidden
            )
        case .windowTitleChanged(let id, _):
            if effects.floatFlipped {
                retile()
            } else {
                // The bars draw titles, so this is a render
                // input — but only a render one. Skipped when
                // the float flip already retiled: that pass
                // rebuilds the bars itself.
                handleTitleChangedForBars(id)
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
        case .desktopChanged:
            handleDesktopChange()
        case .windowRekeyed(let old, let new):
            // The whole id-retarget lives in
            // `KiwiCore+RekeyEvent.swift` (#308).
            handleWindowRekeyed(old: old, new: new)
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
        // A hide, an active own dialog, or a Desktop follow's
        // eager departure stands the raise down —
        // `closeReturnRaiseStandsDown` owns every arm's
        // arguments (#913/#929/#935/#1023). The fold's focus pick
        // still stands: state names the survivor, and the OS's
        // own activation reports it. Guarded on the focus loss
        // so only a removal that would raise pays the seam's
        // NSApplication read.
        let closeReturnRaiseStandsDown =
            effects.removedWindow?.focusLost == true
            && eventLoop.closeReturnRaiseStandsDown(after: event)
        if effects.removedWindow?.focusLost == true,
            !closeReturnRaiseStandsDown,
            let next = activeSpace?.focused,
            eventLoop.isListed(next),
            // Belt to the fold's re-pick (#670): never raise a
            // fullscreen fallback — it would switch the user
            // to its Space on a plain window close.
            state.windows[next]?.isFullscreen != true
        {
            onLog("close-return: raising w\(next.raw)")
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
        // minimize). A removal whose return raise stood down
        // arms no restore either (#936): the drain ends in a
        // focus re-raise of the very anchor the stand-down
        // refused — the next mutation's arm heals the pile.
        if willRetile, !closeReturnRaiseStandsDown {
            scheduleTrackZOrderRestoreIfOverflowing()
        }
        // #951/#952 diagnosis: narrate the decision above.
        // AFTER the tail on purpose — the needle windows in
        // `CloseReturnStandDownWiringTests` span the definition
        // and both consulting sites, and an insert between them
        // overflows the scan's char budget.
        logCloseReturnDecision(
            event: event,
            effects: effects,
            standsDown: closeReturnRaiseStandsDown
        )
    }
}
