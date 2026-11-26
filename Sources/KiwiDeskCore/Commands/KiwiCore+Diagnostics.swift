import CoreGraphics
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
        let tiled = state.effectiveTiledMembers(of: space)
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

    /// Each screen with its frame and the area its shown Space lays
    /// windows out in, in the AX coordinates `list_windows`
    /// reports (#2492), listed as Screen 1 onwards (#3647).
    func listMonitors() -> CommandResponse {
        let primary = GeometryUtils.primaryHeight
        let mainID = PositionalDisplays.liveMainID
        let numbered = numberedScreens(state.workspaces.allDisplays)
        let rest = state.workspaces.allDisplays
            .filter { display in
                !numbered.contains { $0.display.id == display.id }
            }
            .sorted(by: ScreenOrder.precedes)
            .map { (number: Int?.none, display: $0) }
        let ordered =
            numbered.map { (number: Int?($0), display: $1) }
            + rest
        let monitors = ordered.map { number, display in
            let frame = GeometryUtils.flip(
                display.frame,
                primaryHeight: primary
            )
            // Its first area's Space, so a split screen answers one
            // Space whatever has focus (#3517); `areas[]` has each.
            let shown = state.workspaces.leadPlacement(of: display.id)
                .flatMap { state.workspaces.activeSpace(on: $0) }
                .flatMap { state.workspaces[$0] }
            let laid = TilingEngine.screen(for: display.id).flatMap {
                screen in
                shown.map { tiler.layoutBounds(on: screen, for: $0) }
            }
            return JSONValue.object([
                "id": .number(Double(display.id.raw)),
                "name": .string(display.name),
                "frame": Self.json(rect: frame),
                "layout_frame": laid.map(Self.json(rect:)) ?? .null,
                "fingerprint": .string(display.fingerprint),
                "screen": number.map { .number(Double($0)) } ?? .null,
                "main": .bool(display.id == mainID),
                // The Space its first area shows, `get_state`'s
                // `shown` Space there (#3549, #3517).
                "space_id": shown.map { .string($0.id.raw) } ?? .null,
                "areas": areasJSON(of: display, screen: number),
            ])
        }
        return .ok(.array(monitors))
    }

    func stateJSON() -> JSONValue {
        // The same set `list_windows`' `shown` reads (#3549).
        let shown = state.workspaces.visibleSpaces
        let spaces = state.workspaces.allSpaces.map { space in
            let display = state.workspaces.display(of: space.id)
            var object: [String: JSONValue] = [
                "id": .string(space.id.raw),
                // The screen it sits on, the `list_monitors` id.
                "display": display.map { .number(Double($0.raw)) }
                    ?? .null,
                // That screen's `list_monitors` fingerprint, which
                // every screen verb takes (#3628).
                "fingerprint": display.flatMap(screenFingerprint(of:))
                    .map { .string($0) } ?? .null,
                "shown": .bool(shown.contains(space.id)),
                // Its area's key on a split screen, `list_monitors`'
                // `areas[].key` (#3517); null on an unsplit one.
                "area": splitArea(of: space.id).map { .string($0.key) }
                    ?? .null,
                "mode": .string(space.mode.rawValue),
                "windows": .array(
                    space.windows.map {
                        .number(Double($0.raw))
                    }
                ),
                "focused": space.focused.map {
                    .number(Double($0.raw))
                } ?? .null,
                // The space's windows on Desktops nobody shows
                // (#1146), by the rank they return in.
                "away_windows": .array(
                    awayMembers(of: space.id).map {
                        .number(Double($0.raw))
                    }
                ),
            ]
            // The side a Stack Space draws on the Desktop shown
            // now, its flip included (#2771).
            if space.mode == .stack {
                object["stack_position"] = .string(
                    drawnStackPosition(of: space.id).rawValue
                )
            }
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
            // A push's run lengths (#2709), as shares of the span.
            if !space.runSizes.isEmpty {
                object["run_sizes"] = .object(
                    Dictionary(
                        uniqueKeysWithValues: space.runSizes.map {
                            (
                                String($0.key.raw),
                                .number(Double($0.value.share))
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
                // `focus_or_spawn` take — surfaced here so a
                // power user can read it straight off a window.
                "bundle_id": window.appBundleID.map {
                    .string($0)
                } ?? .null,
                "title": .string(window.title),
                "floating": .bool(window.isFloating),
                // "pocketed" / "out", null outside the pocket (#2446).
                "pocket": state.pocketPhase(of: window.id)
                    .map { .string($0.rawValue) } ?? .null,
            ])
        }
        // Every away window, the unfiled ones included (#1146);
        // `desktop` is its Mission Control number, resolved
        // against one topology reading.
        let topology = NativeSpaces.allSpaces()
        let away = state.awayWindows.values
            .sorted { $0.id.raw < $1.id.raw }
            .map { entry in
                JSONValue.object([
                    "id": .number(Double(entry.id.raw)),
                    "app": .string(entry.appName),
                    "bundle_id": entry.appBundleID.map {
                        .string($0)
                    } ?? .null,
                    "space_id": state.rememberedSpace(of: entry.id)
                        .map { .string($0.raw) } ?? .null,
                    "up": .bool(entry.isUp),
                    "desktop": NativeSpaces.number(
                        of: entry.nativeSpace,
                        in: topology
                    ).map { .number(Double($0)) } ?? .null,
                ])
            }
        return .object([
            "active_space": state.workspaces.activeSpace.map {
                .string($0.raw)
            } ?? .null,
            "spaces": .array(spaces),
            "windows": .array(windows),
            "away_windows": .array(away),
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
