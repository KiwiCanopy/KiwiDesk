import AppKit
import Foundation

/// Command execution: the single entry point shared by the
/// Lua API, the CLI, and the IPC socket.
extension KiwiCore {
    @discardableResult
    public func execute(
        _ command: String,
        args: [JSONValue] = []
    ) -> CommandResponse {
        // Fail closed before dispatch when a focused-window command
        // is issued while an ignored panel or unmanaged app holds
        // the foreground (#292). Inert until `start()` wires the
        // provider, so this never fires in unit tests.
        if let denial = focusedCommandDenial(for: command) {
            return denial
        }
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
        case "move_space_to_display":
            return moveSpaceToDisplay(args)
        case "pin_space_to_display":
            return pinSpaceToDisplay(args)
        case "create_space":
            return createSpace(args)
        case "delete_space":
            return deleteSpace(args)
        case "make_floating":
            return setFocusedFloating(true)
        case "make_tiled":
            return setFocusedFloating(false)
        case "make_auto":
            return setFocusedAuto()
        case "toggle_floating":
            return toggleFocusedFloating()
        case "make_sticky":
            return setFocusedSticky(.global)
        case "make_display_sticky":
            return setFocusedSticky(.display)
        case "make_unsticky":
            return setFocusedSticky(.none)
        case "toggle_sticky":
            return toggleFocusedSticky(.global)
        case "toggle_display_sticky":
            return toggleFocusedSticky(.display)
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
        case "set_float_nudge":
            return setFloatNudge(args)
        case "set_float_scale_on_display_change":
            return setFloatScaleOnDisplayChange(args)
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
        case let quit where quit.hasPrefix("quit."):
            // A teardown-only setting: dispatched here (not
            // via layoutCommand's forced-retile trailer)
            // because it is read only when the app stops — a
            // live retile would be a pure no-op. Same policy
            // as `track.swap` above.
            return quitCommand(command, args)
        default:
            return layoutCommand(command, args)
        }
    }

    // MARK: - Window state

    private func setFocusedFloating(
        _ floating: Bool
    ) -> CommandResponse {
        guard let focused = focusedWindowID else {
            return .fail("no focused window")
        }
        // Snapshot before the flip so the nudge fires on the
        // tiled→floating transition only — not on a re-issued
        // `make_floating` for an already-floating window.
        let wasFloating =
            state.windows[focused]?.isFloating ?? false
        state.setFloating(focused, floating)
        retile()
        // Float direction only: `make_tiled` already animates a
        // real move back into the layout, so no nudge there.
        if floating, !wasFloating {
            nudgeFloating(focused)
        }
        return .ok()
    }

    /// `toggle_floating` (#221): flip the focused window between
    /// floating and tiled in one verb. Reads the window's
    /// *effective* state and writes the explicit opposite as a
    /// manual override — like `make_floating`/`make_tiled`, it
    /// never yields `auto` (that stays `make_auto`'s job), so the
    /// #164 tri-state is preserved by construction.
    private func toggleFocusedFloating() -> CommandResponse {
        guard
            let focused = focusedWindowID,
            let window = state.windows[focused]
        else {
            return .fail("no focused window")
        }
        return setFocusedFloating(!window.isFloating)
    }

    /// `make_sticky` / `make_display_sticky` / `make_unsticky`
    /// (#414/#445): sets the focused window's sticky SCOPE. No
    /// tri-state and no detection source — the scope is the whole
    /// story, and each verb writes its own scope outright, so
    /// `make_sticky` on a display-sticky window turns it global and
    /// vice versa (the #221 sibling-verb model). The window keeps
    /// its float/tiled state; the retile applies the effect (stash
    /// exemption, traveler injection) at once.
    private func setFocusedSticky(
        _ scope: StickyScope
    ) -> CommandResponse {
        guard let focused = focusedWindowID else {
            return .fail("no focused window")
        }
        state.setSticky(focused, scope)
        retile()
        return .ok()
    }

    /// `toggle_sticky` / `toggle_display_sticky` (#414/#445): the
    /// everyday sticky verbs, the two offered in the Settings
    /// shortcut list (#221 precedent). Each toggles ITS scope
    /// against off: already in `scope` → off; anything else
    /// (unsticky OR the other scope) → `scope`. So toggling display
    /// on a global sticky switches it to display, matching the
    /// `make_*` override semantics.
    private func toggleFocusedSticky(
        _ scope: StickyScope
    ) -> CommandResponse {
        guard
            let focused = focusedWindowID,
            let window = state.windows[focused]
        else {
            return .fail("no focused window")
        }
        let next: StickyScope =
            window.stickyScope == scope ? .none : scope
        return setFocusedSticky(next)
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
        guard let focused = focusedWindowID else {
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
        guard
            let bundleID = args.first?.stringValue?.lowercased()
        else {
            return .fail("expected app bundle id")
        }
        // Already focused: advance to the app's next window
        // (#637) — checked first, off tracked state alone, so
        // the repeat press cycles instead of re-activating.
        if !newInstance,
            cycleToNextWindow(bundleID: bundleID)
        {
            return .ok()
        }
        // Pull an existing instance forward, matched by bundle
        // id (locale- and rename-proof, unlike the display
        // name — see AppRef).
        if !newInstance,
            let running = NSWorkspace.shared
                .runningApplications
                .first(where: {
                    $0.bundleIdentifier?.lowercased() == bundleID
                })
        {
            // `activate()` does not deminiaturize, so an app whose
            // windows are ALL minimized came forward showing
            // nothing at all (#673). Restore exactly one first —
            // the most recently minimized, the Dock's precedent
            // for clicking an app icon — and leave the rest
            // parked.
            restoreOneMinimizedIfNothingVisible(
                pid: running.processIdentifier,
                bundleID: bundleID
            )
            running.activate()
            return .ok()
        }
        // LaunchServices resolves the bundle id to its install
        // location — finds apps the old /Applications path scan
        // missed (Finder in CoreServices, apps in ~/Applications).
        guard
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleID
            )
        else {
            return .fail("app not found: \(bundleID)")
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = newInstance
        NSWorkspace.shared.openApplication(
            at: url,
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
        setSpaceMode(spaceID, mode)
        // Forced: an explicit config apply (AGENTS.md §5),
        // like the layoutCommand dispatch.
        retile(force: true)
        if let space = state.workspaces[spaceID] {
            emitLayoutChange(space: space)
        }
        return .ok()
    }

}
