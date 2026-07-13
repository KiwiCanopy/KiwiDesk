import AppKit
import Foundation

/// Command execution: the single entry point shared by the
/// Lua API, the CLI, and the IPC socket (see 04_API_Contract).
extension KiwiCore {
    public func execute(
        _ command: String,
        args: [JSONValue] = []
    ) -> CommandResponse {
        switch command {
        case "focus":
            return navigate(args, swapping: false)
        case "swap":
            return navigate(args, swapping: true)
        case "focus_space":
            return focusSpace(args)
        case "move_to_space":
            return moveToSpace(args, follow: false)
        case "move_to_space_and_follow":
            return moveToSpace(args, follow: true)
        case "make_floating":
            return setFocusedFloating(true)
        case "make_tiled":
            return setFocusedFloating(false)
        case "make_auto":
            return setFocusedAuto()
        case "resize":
            return resize(args)
        case "move_to_track":
            return moveToTrack(args)
        case "track.swap":
            // An action, not a config setter: dispatched here
            // (not via layoutCommand's forced-retile trailer)
            // so it self-retiles under `on_window_swap`, the
            // same policy as its sibling `move_to_track`.
            return trackSwap(args)
        case "pull_or_spawn":
            return launch(args, newInstance: false)
        case "spawn_new":
            return launch(args, newInstance: true)
        case "set_mode":
            return setMode(args)
        case "set_gap_global", "set_gap_override":
            return setGaps(command, args)
        case "set_min_window_size":
            return setMinWindowSize(args)
        case "set_swap_skips_cascade":
            return setSwapSkipsCascade(args)
        case "set_resize_step":
            return setResizeStep(args)
        case "set_resize_feedback":
            return setResizeFeedback(args)
        case "help", "list_commands":
            return .ok(
                .array(
                    APIReference.allCommands.map {
                        .string($0)
                    }
                )
            )
        case "version":
            return .ok(
                .object([
                    "version": .string(
                        KiwiDeskVersion.semantic
                    ),
                    "commit": .string(KiwiDeskVersion.commit),
                ])
            )
        case "get_state":
            return .ok(stateJSON())
        case "get_layout_info":
            return layoutInfo()
        case "list_monitors":
            return listMonitors()
        case "debug_log":
            onLog(args.first?.stringValue ?? "")
            return .ok()
        case "reload_config":
            // Deferred: Lua may be calling us right now, and
            // reloading destroys the running VM.
            Task { @MainActor [weak self] in
                self?.loadConfig()
            }
            return .ok(.string("reloading"))
        case "save_profile", "load_profile",
            "delete_profile", "set_default_profile",
            "list_profiles", "get_profile_status":
            return profileCommand(command, args)
        case "bind_profile_to_native_space":
            return bindProfileToNativeSpace(args)
        default:
            return layoutCommand(command, args)
        }
    }

    /// Focuses a window: state, AX raise, and — only for
    /// focus-driven layouts (Scrolling, Monocle) — a retile.
    /// Static layouts skip it: their targets are unchanged,
    /// and re-applying them just fights apps that clamp our
    /// frames (grid-snapping terminals), wobbling everything.
    /// In scrolling, the raise waits for the pan to settle
    /// (#143, see `runPendingFocusRaise`).
    ///
    /// `refocusRetile: false` suppresses that retile for callers
    /// that just retiled themselves — a space switch already
    /// placed windows with the correct focus, and re-tiling here
    /// would spring them from their stale stash-corner frames
    /// (the AX echo of the instant switch has not landed yet),
    /// which is the "fly out of the corner" bug (issue #11).
    public func focusWindow(
        _ id: WindowID,
        refocusRetile: Bool = true,
        warp: Bool
    ) {
        let previousFocused = activeSpace?.focused
        let space = state.workspaces.space(of: id)
        if let space {
            state.workspaces.focus(id, in: space)
        }
        // Scrolling defers the raise until the pan settles
        // (#143), but only when stepping *backward* toward the
        // row pinned behind the leading edge (up/left): raising
        // it first pops that pinned row over the whole screen
        // before the slide even starts. Stepping forward
        // (down/right) — and the neighbor handoff after a close —
        // raises immediately, so the newly focused window lays on
        // top as it slides in instead of waiting out the pan.
        // State focus stays immediate either way: the layout
        // needs it to compute the pan. Every other path (monocle,
        // static layouts, space switches, cross-space focus)
        // keeps raise-first: there the raise IS the visible
        // focus change.
        let defersRaise =
            refocusRetile
            && activeSpace?.mode.defersFocusRaise == true
            && space == state.workspaces.activeSpace
            && scrollFocusStepsBackward(
                to: id,
                from: previousFocused
            )
        if !defersRaise {
            raiseWindow(id)
        }
        // Mouse follows focus (#186) fires at the intent point,
        // strictly AFTER the raise: synthetic CG mouse activity
        // right before `NSRunningApplication.activate()` can
        // make macOS's cooperative activation drop the request
        // (raise lands, key focus doesn't). State focus is set
        // (scrolling slot frames final); the raise echo is a
        // self-echo that must not warp twice. `warp: false`
        // marks mouse-made focus (drag drop, resize settle),
        // where the button is already up.
        if warp { warpMouseToFocused(id) }
        guard refocusRetile,
            activeSpace?.mode.isFocusDriven == true
        else {
            // Unreachable while `defersFocusRaise` stays a
            // subset of `isFocusDriven` — but if that drifts,
            // never lose the raise.
            if defersRaise { raiseWindow(id) }
            return
        }
        retileWithScrollDuration()
        // Armed only AFTER the retile: retiling cancels
        // in-tolerance animations one by one, and the settle
        // callback fires synchronously the moment the count
        // hits zero — a pending raise armed before that would
        // fire mid-retile, ahead of the new pan (the #143 pop
        // again). Nothing can interleave between these
        // synchronous main-actor statements.
        if defersRaise {
            pendingFocusRaise = id
            // No pan in flight (target already visible, or
            // animations off): raise immediately — the
            // deferral must not regress non-animated paths.
            if tiler.animation.activeCount == 0 {
                runPendingFocusRaise()
            }
        }
    }

    /// Whether a scrolling focus move steps to an earlier slot
    /// than the previously focused window — the row pinned behind
    /// the leading edge. Only that direction defers the raise
    /// (#143); stepping forward, a first focus, and the
    /// close-handoff (`previous == target`) all raise at once.
    /// Compares tiled array indices: array order is scroll order,
    /// so a lower index is up/left along the resolved axis.
    private func scrollFocusStepsBackward(
        to target: WindowID,
        from previous: WindowID?
    ) -> Bool {
        guard let previous, previous != target,
            let space = activeSpace
        else { return false }
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard let targetIndex = tiled.firstIndex(of: target),
            let previousIndex = tiled.firstIndex(of: previous)
        else { return false }
        return targetIndex < previousIndex
    }

    /// Whether a focus-driven re-layout animates. Scrolling's
    /// focus slide is toggleable (`on_scrolling`); other
    /// focus-driven modes (Monocle) always animate. Used by
    /// `retileWithScrollDuration`'s non-scrolling branch — the
    /// scrolling branch swaps in `scrollDurationMS` and always
    /// animates when `on_scrolling` is set.
    var focusRetileAnimated: Bool {
        activeSpace?.mode == .scrolling
            ? tiler.settings.animations.onScrolling : true
    }

    /// Retiles for a focus-driven layout, honouring
    /// `scrollDurationMS` when the active mode is scrolling and
    /// `onScrolling` is true — so scroll focus shifts animate at
    /// their own speed without touching the general duration.
    ///
    /// Safe to call on MainActor: `retile()` is synchronous and
    /// reads `durationMS` at call time, so the transient swap
    /// cannot race anything.
    func retileWithScrollDuration() {
        if activeSpace?.mode == .scrolling,
            tiler.settings.animations.onScrolling
        {
            let saved = tiler.animation.durationMS
            tiler.animation.durationMS =
                tiler.animation.scrollDurationMS
            retile(animated: true)
            tiler.animation.durationMS = saved
        } else {
            retile(animated: focusRetileAnimated)
        }
    }

    // MARK: - Window state

    private func setFocusedFloating(
        _ floating: Bool
    ) -> CommandResponse {
        guard let focused = activeSpace?.focused else {
            return .fail("no focused window")
        }
        state.setFloating(focused, floating)
        retile()
        return .ok()
    }

    /// `make_auto` (#164): clears the focused window's manual
    /// float override and returns it to detection control by
    /// re-applying the event loop's cached verdict. Without a
    /// cached verdict (untracked window) the current state
    /// stands until the next detection pass.
    ///
    /// Feeds the fold directly instead of `KiwiCore.handle`
    /// (like `setFocusedFloating`): commands own their retile.
    /// If `handle` ever grows a `windowFloatChanged` side
    /// effect (bus emit), mirror it here.
    private func setFocusedAuto() -> CommandResponse {
        guard let focused = activeSpace?.focused else {
            return .fail("no focused window")
        }
        state.clearFloatOverride(focused)
        if let detected = eventLoop.detectionVerdict(
            for: focused
        ) {
            state.apply(
                .windowFloatChanged(
                    focused,
                    isFloating: detected
                )
            )
        }
        retile()
        return .ok()
    }

    // `resize` lives in `KiwiCore+Resize.swift` (#56/#67).

    // MARK: - Launching

    private func launch(
        _ args: [JSONValue],
        newInstance: Bool
    ) -> CommandResponse {
        guard let name = args.first?.stringValue else {
            return .fail("expected app name")
        }
        if !newInstance,
            let running = NSWorkspace.shared
                .runningApplications
                .first(where: { $0.localizedName == name })
        {
            running.activate()
            return .ok()
        }
        let candidates = [
            "/Applications/\(name).app",
            "/System/Applications/\(name).app",
        ]
        guard
            let path = candidates.first(
                where: {
                    FileManager.default.fileExists(atPath: $0)
                }
            )
        else {
            return .fail("app not found: \(name)")
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = newInstance
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: path),
            configuration: config
        )
        return .ok()
    }

    // MARK: - Modes and gaps

    private func setMode(
        _ args: [JSONValue]
    ) -> CommandResponse {
        let spaceID: SpaceID?
        let modeArg: JSONValue?
        if args.count >= 2 {
            spaceID = args[0].stringValue.map { SpaceID($0) }
            modeArg = args[1]
        } else {
            spaceID = state.workspaces.activeSpace
            modeArg = args.first
        }
        guard let spaceID,
            let raw = modeArg?.stringValue,
            let mode = LayoutMode(rawValue: raw)
        else {
            return .fail("expected [space,] mode")
        }
        state.workspaces.ensureSpace(spaceID)
        state.workspaces.setMode(spaceID, mode)
        // Forced: an explicit config apply (AGENTS.md §5),
        // like the layoutCommand dispatch.
        retile(force: true)
        if let space = state.workspaces[spaceID] {
            emitLayoutChange(space: space)
        }
        return .ok()
    }

}
