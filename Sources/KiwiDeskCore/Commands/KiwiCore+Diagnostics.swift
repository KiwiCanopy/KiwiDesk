import Foundation

/// Diagnostic commands: `get_state`, `get_layout_info`,
/// `list_monitors`.
extension KiwiCore {
    /// One diagnostic line per space switch: how many windows
    /// the space holds and how many actually tile. "0
    /// windows" right after a restart means the startup scan
    /// missed them; "0 tiled" means wrong float verdicts.
    func logSpaceContents(_ id: SpaceID) {
        guard let space = state.workspaces[id] else { return }
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        onLog(
            "space \(id.raw): \(space.windows.count) windows, "
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
            var object: [String: JSONValue] = [
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
            ]
            // Session-only stack weights (#67), surfaced so
            // resize("y") state is inspectable from the CLI;
            // absent while the column is evenly split.
            if !space.stackWeights.isEmpty {
                object["stack_weights"] = .object(
                    Dictionary(
                        uniqueKeysWithValues:
                            space.stackWeights.map {
                                (
                                    String($0.key.raw),
                                    JSONValue.number($0.value)
                                )
                            }
                    )
                )
            }
            // Session-only track partition (#128), same
            // rationale as stack_weights: break markers and
            // per-head track weights, absent outside track
            // stints.
            if !space.trackBreaks.isEmpty {
                object["track_breaks"] = .array(
                    space.trackBreaks
                        .map(\.raw).sorted()
                        .map { .number(Double($0)) }
                )
            }
            if !space.trackWeights.isEmpty {
                object["track_weights"] = .object(
                    Dictionary(
                        uniqueKeysWithValues:
                            space.trackWeights.map {
                                (
                                    String($0.key.raw),
                                    JSONValue.number($0.value)
                                )
                            }
                    )
                )
            }
            return JSONValue.object(object)
        }
        let windows = state.windows.all.map { window in
            JSONValue.object([
                "id": .number(Double(window.id.raw)),
                "app": .string(window.appName),
                // The bundle id is the value app rules
                // (`float_rules`, `app_rules`) and
                // `pull_or_spawn` take — surfaced here so a
                // power user can read it straight off a window.
                "bundle_id": window.appBundleID.map {
                    .string($0)
                } ?? .null,
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
            // The active Desktop — the MAIN display's current
            // one (#888) — for setting up
            // bind_profile_to_desktop. Null without
            // SkyLight.
            "desktop": NativeSpaces.activeDesktopNumber()
                .map { .number(Double($0)) } ?? .null,
            // Exec children still running; useful for
            // debugging config hooks (issue #37).
            "exec_running": .number(
                Double(exec.runningCount)
            ),
        ])
    }
}
