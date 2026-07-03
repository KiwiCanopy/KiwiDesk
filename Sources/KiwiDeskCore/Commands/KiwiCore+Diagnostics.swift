import Foundation

/// Diagnostic commands: `get_state`, `get_layout_info`,
/// `list_monitors`.
extension KiwiCore {
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
        ])
    }
}
