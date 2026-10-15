import AppKit

/// `explain_window` and `explain_app` (#1685 ▸ Ruling 6d): why a
/// window floats or tiles and where it opens, as structure read
/// from the doors that decide it — never re-detected here. Neither
/// answer carries a window title.
extension KiwiCore {
    /// `explain_window [window]`: the named window, else the
    /// focused one (#1518).
    func explainWindow(_ args: [JSONValue]) -> CommandResponse {
        switch commandTarget("explain_window", args) {
        case .refused(let response): return response
        case .window(let id):
            guard let window = state.windows[id] else {
                return .fail("unknown window: \(id.raw)")
            }
            let space = state.workspaces.space(of: id)
            let mode = space.flatMap { state.workspaces[$0]?.mode }
            return .ok(
                .object([
                    "window": .number(Double(id.raw)),
                    "app": .string(window.appName),
                    "bundle_id": window.appBundleID.map {
                        .string($0)
                    } ?? .null,
                    "space_id": space.map { .string($0.raw) } ?? .null,
                    "space_mode": mode.map { .string($0.rawValue) }
                        ?? .null,
                    "floating": floating(window, mode: mode),
                    "app_rule": appRuleFacts(window.appBundleID),
                    "sticky": .string(window.stickyScope.rawValue),
                    "fullscreen": .bool(window.isFullscreen),
                    "presenting": .bool(presents(id, at: window.frame)),
                    "focused": .bool(focusedWindowID == id),
                ])
            )
        }
    }

    /// Whether the window floats, and WHY: detection's verdict
    /// through the one `tileRefusal(of:)` door, else the user's
    /// own float, else a floating-mode Space.
    private func floating(
        _ window: ManagedWindow,
        mode: LayoutMode?
    ) -> JSONValue {
        let reason = tileRefusal(of: window.id)
        let flag = window.isFloating
        let cause: JSONValue =
            if reason != nil {
                .string("detection")
            } else if flag {
                .string("user")
            } else if mode == .floating {
                .string("space_mode")
            } else {
                .null
            }
        let detection: JSONValue =
            reason.map {
                .object([
                    "reason": .string($0.wireName),
                    "is_guess": .bool($0.isGuess),
                    "escapes": .array($0.escapes.map(JSONValue.string)),
                ])
            } ?? .null
        return .object([
            "floats": .bool(
                EffectiveFloat.applies(isFloating: flag, mode: mode)
            ),
            "flag": .bool(flag),
            "cause": cause,
            "detection": detection,
        ])
    }

    /// `explain_app <bundle_id>`: what KiwiDesk knows of an app
    /// whose window `get_state` may not list — ignored, minimized,
    /// hidden or away. An app nothing knows answers empty lists.
    func explainApp(_ args: [JSONValue]) -> CommandResponse {
        let app = args.first?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let app, !app.isEmpty else {
            return .fail("expected an app's bundle id")
        }
        let windows = state.windows.all
            .filter { $0.appBundleID?.lowercased() == app }
            .map { JSONValue.number(Double($0.id.raw)) }
        let minimized = state.minimizeOrder
            .filter { $0.bundleID?.lowercased() == app }
            .map { JSONValue.number(Double($0.id.raw)) }
        let away = awayWindows(bundleID: app).map {
            JSONValue.object([
                "id": .number(Double($0.id.raw)),
                "space_id": state.rememberedSpace(of: $0.id).map {
                    .string($0.raw)
                } ?? .null,
            ])
        }
        return .ok(
            .object([
                "app": .string(app),
                "ignored": .object([
                    "by_rule": .bool(
                        eventLoop.ignoreRules.matches(bundleID: app)
                    ),
                    "built_in": .bool(
                        FloatDetection.isBuiltInIgnoredApp(bundleID: app)
                    ),
                    "raised_windows": .bool(
                        FloatDetection.ignoresRaisedWindows(
                            bundleID: app
                        )
                    ),
                ]),
                "running": .array(runningProcesses(of: app)),
                "windows": .array(windows),
                "minimized": .array(minimized),
                "away": .array(away),
                "app_rule": appRuleFacts(app),
            ])
        )
    }

    /// The app's live processes, each with whether KiwiDesk
    /// observes it, its activation policy and whether it is
    /// hidden — through the event loop's one reading of each.
    private func runningProcesses(of app: String) -> [JSONValue] {
        eventLoop.liveApps()
            .filter { $0.ref.bundleID == app }
            .map { running in
                .object([
                    "pid": .number(Double(running.pid)),
                    "observed": .bool(eventLoop.observes(pid: running.pid)),
                    "policy": .string(
                        Self.wireName(eventLoop.policy(of: running.pid))
                    ),
                    "hidden": .bool(eventLoop.appIsHidden(running.pid)),
                ])
            }
    }

    private static func wireName(
        _ policy: NSApplication.ActivationPolicy
    ) -> String {
        switch policy {
        case .regular: "regular"
        case .accessory: "accessory"
        case .prohibited: "prohibited"
        @unknown default: "unknown"
        }
    }
}
