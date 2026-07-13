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
        case "toggle_floating":
            return toggleFocusedFloating()
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

    /// `toggle_floating` (#221): flip the focused window between
    /// floating and tiled in one verb. Reads the window's
    /// *effective* state and writes the explicit opposite as a
    /// manual override — like `make_floating`/`make_tiled`, it
    /// never yields `auto` (that stays `make_auto`'s job), so the
    /// #164 tri-state is preserved by construction.
    private func toggleFocusedFloating() -> CommandResponse {
        guard
            let focused = activeSpace?.focused,
            let window = state.windows[focused]
        else {
            return .fail("no focused window")
        }
        return setFocusedFloating(!window.isFloating)
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
