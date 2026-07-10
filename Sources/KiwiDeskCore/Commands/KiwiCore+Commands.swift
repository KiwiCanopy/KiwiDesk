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
        case "resize":
            return resize(args)
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
        case "set_resize_step":
            return setResizeStep(args)
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
    ///
    /// `refocusRetile: false` suppresses that retile for callers
    /// that just retiled themselves — a space switch already
    /// placed windows with the correct focus, and re-tiling here
    /// would spring them from their stale stash-corner frames
    /// (the AX echo of the instant switch has not landed yet),
    /// which is the "fly out of the corner" bug (issue #11).
    public func focusWindow(
        _ id: WindowID,
        refocusRetile: Bool = true
    ) {
        if let space = state.workspaces.space(of: id) {
            state.workspaces.focus(id, in: space)
        }
        if let window = state.windows[id],
            let element = eventLoop.element(for: id)
        {
            AXHelper.raise(element, pid: window.pid)
        }
        guard refocusRetile,
            activeSpace?.mode.isFocusDriven == true
        else { return }
        retileWithScrollDuration()
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
