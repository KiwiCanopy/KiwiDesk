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
        case "focus_virtual_space":
            return focusSpace(args)
        case "move_to_virtual_space":
            return moveToSpace(args, follow: false)
        case "move_to_virtual_space_and_follow":
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
        case "help", "list_commands":
            return .ok(
                .array(
                    APIReference.allCommands.map {
                        .string($0)
                    }
                )
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
            "list_profiles", "get_profile_status":
            return profileCommand(command, args)
        case "bind_profile_to_native_space":
            return bindProfileToNativeSpace(args)
        default:
            return layoutCommand(command, args)
        }
    }

    // MARK: - Navigation

    private func navigate(
        _ args: [JSONValue],
        swapping: Bool
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = Direction(rawValue: raw)
        else {
            return .fail("expected left|right|up|down")
        }
        guard let space = activeSpace,
            let focused = space.focused
        else {
            return .fail("no focused window")
        }
        // Navigate the layout's slots, not live AX frames:
        // live frames are stale mid-animation or when an app
        // misses a move notification, and cascaded windows
        // overlap anyway. Floating windows (no slot) fall
        // back to their last known frame.
        let slots = tiler.calculatedFrames(state: state)
        guard
            let frame = slots[focused]
                ?? state.windows[focused]?.frame
        else {
            return .fail("no focused window")
        }
        let candidates = space.windows
            .filter {
                $0 != focused
                    && state.windows[$0]?.isFloating == false
            }
            .compactMap { id -> (WindowID, CGRect)? in
                guard
                    let slot = slots[id]
                        ?? state.windows[id]?.frame
                else { return nil }
                return (id, slot)
            }
        guard
            let target = Navigation.neighbor(
                from: frame,
                in: direction,
                candidates: candidates
            )
        else {
            return .fail("no window \(raw) of focus")
        }
        if swapping {
            let crossedZones = crossesStackBoundary(
                focused,
                target,
                in: space
            )
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            retile()
            if crossedZones {
                scheduleStackZOrderRestore()
            }
        } else {
            focusWindow(target)
        }
        return .ok()
    }

    /// Focuses a window: state, AX raise, and — only for
    /// focus-driven layouts (Scrolling, Monocle) — a retile.
    /// Static layouts skip it: their targets are unchanged,
    /// and re-applying them just fights apps that clamp our
    /// frames (grid-snapping terminals), wobbling everything.
    public func focusWindow(_ id: WindowID) {
        if let space = state.workspaces.space(of: id) {
            state.workspaces.focus(id, in: space)
        }
        if let window = state.windows[id],
            let element = eventLoop.element(for: id)
        {
            AXHelper.raise(element, pid: window.pid)
        }
        if activeSpace?.mode.isFocusDriven == true {
            retile()
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

    private func resize(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let axis = args.first?.stringValue,
            axis == "x" || axis == "y",
            let delta = args.dropFirst().first?.numberValue
        else {
            return .fail("expected axis (x|y) and delta")
        }
        guard let space = activeSpace else {
            return .fail("no active space")
        }
        let span =
            axis == "x"
            ? (NSScreen.main?.visibleFrame.width ?? 1920)
            : (NSScreen.main?.visibleFrame.height ?? 1080)
        switch space.mode {
        case .bsp:
            let ratio =
                tiler.settings.bsp.splitRatio
                + delta / Double(span)
            tiler.settings.bsp.splitRatio =
                min(max(ratio, 0.1), 0.9)
        case .stack:
            let ratio =
                tiler.settings.stack.masterRatio
                + delta / Double(span)
            tiler.settings.stack.masterRatio =
                min(max(ratio, 0.1), 0.9)
        case .scrolling:
            let width =
                tiler.settings.scrolling.windowWidth
                + CGFloat(delta)
            tiler.settings.scrolling.windowWidth =
                max(width, 100)
        default:
            return .fail(
                "resize not supported in "
                    + space.mode.rawValue
            )
        }
        retile()
        return .ok()
    }

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
        retile()
        if let space = state.workspaces[spaceID] {
            emitLayoutChange(space: space)
        }
        return .ok()
    }

    private func setGaps(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command == "set_gap_global" {
            guard let size = args.first?.numberValue else {
                return .fail("expected gap size")
            }
            tiler.settings.gapsGlobal = .uniform(
                CGFloat(size)
            )
        } else {
            guard let space = args.first?.stringValue,
                let size = args.dropFirst().first?.numberValue
            else {
                return .fail("expected space id and size")
            }
            tiler.settings.gapsOverride[SpaceID(space)] =
                .uniform(CGFloat(size))
        }
        retile()
        return .ok()
    }
}
