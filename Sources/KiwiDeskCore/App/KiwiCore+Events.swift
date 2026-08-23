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
        // The frame BEFORE this event folds in — the drag
        // coordinator anchors a gesture's start on it (#933);
        // `state.apply` below overwrites it.
        let preEventFrame: CGRect? = {
            switch event {
            case .windowMoved(let id, _),
                .windowResized(let id, _):
                return state.windows[id]?.frame
            default:
                return nil
            }
        }()
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
                    channel: "move echo"
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
                    channel: "resize echo"
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
            forgetGoneWindow(id)
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
        case .windowHidden(let id):
            // Same forgetting as a destroy — the id can be
            // reused whether the window closed or its app hid.
            forgetGoneWindow(id)
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
            // constraint, new id. So does the monocle
            // shown-member hold (#881) — a tab switch on the
            // shown member must not park it.
            tiler.rekeySizeBound(oldID: old, newID: new)
            tiler.rekeyMonocleShown(oldID: old, newID: new)
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
        // A hide, or an active own dialog, stands the raise
        // down — `closeReturnRaiseStandsDown` owns both arms'
        // arguments (#913/#929/#935). The fold's focus pick
        // still stands: state names the survivor, and the OS's
        // own activation reports it.
        let closeReturnRaiseStandsDown =
            eventLoop.closeReturnRaiseStandsDown(after: event)
        if effects.removedWindow?.focusLost == true,
            !closeReturnRaiseStandsDown,
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
        // minimize). A removal whose return raise stood down
        // arms no restore either (#936): the drain ends in a
        // focus re-raise of the very anchor the stand-down
        // refused — the next mutation's arm heals the pile.
        if willRetile,
            !(effects.removedWindow?.focusLost == true
                && closeReturnRaiseStandsDown)
        {
            scheduleTrackZOrderRestoreIfOverflowing()
        }
    }
}
