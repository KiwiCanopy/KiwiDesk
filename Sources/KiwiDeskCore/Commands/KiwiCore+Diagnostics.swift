import Foundation

/// Diagnostic commands: `get_state`, `get_layout_info`,
/// `list_monitors`.
extension KiwiCore {
    /// One diagnostic line per space switch: how many windows
    /// the space holds and how many actually tile. "0
    /// windows" right after a restart means the startup scan
    /// missed them; "0 tiled" means wrong float verdicts.
    func logSpaceContents(_ id: SpaceID) {
        let members = state.workspaces[id]?.windows ?? []
        let tiled = members.filter {
            state.windows[$0]?.isFloating == false
        }
        onLog(
            "space \(id.raw): \(members.count) windows, "
                + "\(tiled.count) tiled"
        )
    }

    func layoutInfo() -> CommandResponse {
        guard let space = activeSpace else {
            return .fail("no active space")
        }
        return .ok(
            .object([
                "space_id": .string(space.id.raw),
                "mode": .string(space.mode.rawValue),
                "window_count": .number(
                    Double(space.windows.count)
                ),
                "focused": space.focused.map {
                    .number(Double($0.raw))
                } ?? .null,
            ])
        )
    }

    func listMonitors() -> CommandResponse {
        let monitors = state.workspaces.allDisplays.map {
            display in
            JSONValue.object([
                "id": .number(Double(display.id.raw)),
                "name": .string(display.name),
                "width": .number(Double(display.frame.width)),
                "height": .number(
                    Double(display.frame.height)
                ),
                "fingerprint": .string(display.fingerprint),
            ])
        }
        return .ok(.array(monitors))
    }

    func stateJSON() -> JSONValue {
        let spaces = state.workspaces.allSpaces.map { space in
            JSONValue.object([
                "id": .string(space.id.raw),
                "mode": .string(space.mode.rawValue),
                "windows": .array(
                    space.windows.map {
                        .number(Double($0.raw))
                    }
                ),
                "focused": space.focused.map {
                    .number(Double($0.raw))
                } ?? .null,
            ])
        }
        let windows = state.windows.all.map { window in
            JSONValue.object([
                "id": .number(Double(window.id.raw)),
                "app": .string(window.appName),
                "title": .string(window.title),
                "floating": .bool(window.isFloating),
            ])
        }
        return .object([
            "active_space": state.workspaces.activeSpace.map {
                .string($0.raw)
            } ?? .null,
            "spaces": .array(spaces),
            "windows": .array(windows),
            "monitor_count": .number(
                Double(state.workspaces.allDisplays.count)
            ),
            // Mission Control desktop number, for setting up
            // bind_profile_to_native_space. Null without
            // SkyLight.
            "native_space": NativeSpaces.activeSpaceNumber()
                .map { .number(Double($0)) } ?? .null,
            // Exec children still running; useful for
            // debugging config hooks (issue #37).
            "exec_running": .number(
                Double(exec.runningCount)
            ),
        ])
    }
}
