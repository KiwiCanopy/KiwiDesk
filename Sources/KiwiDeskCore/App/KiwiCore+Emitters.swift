import Foundation

/// Event emission helpers: bridge state changes onto the
/// EventBus for Lua callbacks and the CLI event stream.
extension KiwiCore {
    func emitSpaceChange() {
        guard let id = state.workspaces.activeSpace,
            let space = state.workspaces[id]
        else { return }
        bus.emit(
            .spaceChange,
            data: .object([
                "space_id": .string(id.raw),
                "layout_mode": .string(space.mode.rawValue),
                "window_count": .number(
                    Double(space.windows.count)
                ),
            ]),
            luaArgs: [
                .string(id.raw),
                .string(space.mode.rawValue),
            ]
        )
    }

    func emitLayoutChange(space: Space) {
        bus.emit(
            .layoutChange,
            data: .object([
                "space_id": .string(space.id.raw),
                "layout_mode": .string(space.mode.rawValue),
            ]),
            luaArgs: [
                .string(space.id.raw),
                .string(space.mode.rawValue),
            ]
        )
    }

    func emitFocusChange(_ id: WindowID) {
        let window = state.windows[id]
        bus.emit(
            .focusChange,
            data: .object([
                "window_id": .number(Double(id.raw)),
                "app": .string(window?.appName ?? ""),
                "title": .string(window?.title ?? ""),
                "bundle_id": bundleValue(window?.appBundleID),
            ]),
            luaArgs: [
                .number(Double(id.raw)),
                .string(window?.appName ?? ""),
                .string(window?.appBundleID ?? ""),
            ]
        )
    }

    /// `bundle_id` payload convention, matching `get_state`:
    /// string in `data` when known, JSON null when not; the
    /// positional Lua arg uses `""` so the list can't truncate.
    private func bundleValue(_ id: String?) -> JSONValue {
        id.map { .string($0) } ?? .null
    }

    func emitMonitorChange() {
        let displays = state.workspaces.allDisplays
        bus.emit(
            .monitorChange,
            data: .object([
                "count": .number(Double(displays.count))
            ]),
            luaArgs: [.number(Double(displays.count))]
        )
    }

    // MARK: - Window lifecycle (issue #20)

    /// Fires after state placed the new window, so `space`
    /// reflects app_rules / spawn placement. `reason` is
    /// classified by handle() before state.apply (#40).
    func emitWindowCreated(
        _ window: ManagedWindow,
        reason: WindowAppearReason
    ) {
        let space = state.workspaces.space(of: window.id)
        bus.emit(
            .windowCreated,
            data: .object([
                "window_id": .number(Double(window.id.raw)),
                "app": .string(window.appName),
                "space_id": space.map { .string($0.raw) }
                    ?? .null,
                "reason": .string(reason.rawValue),
                "bundle_id": bundleValue(window.appBundleID),
            ]),
            luaArgs: [
                .number(Double(window.id.raw)),
                .string(window.appName),
                .string(space?.raw ?? ""),
                .string(reason.rawValue),
                .string(window.appBundleID ?? ""),
            ]
        )
    }

    /// Fires on an explicit single-window move
    /// (`move_to_space`); bulk reassignments
    /// (snapshot restore, profile load) stay silent.
    func emitWindowMovedToSpace(
        _ id: WindowID,
        app: String,
        bundleID: String?,
        from: SpaceID?,
        to: SpaceID
    ) {
        bus.emit(
            .windowMovedToSpace,
            data: .object([
                "window_id": .number(Double(id.raw)),
                "app": .string(app),
                "from_space_id": from.map {
                    .string($0.raw)
                } ?? .null,
                "to_space_id": .string(to.raw),
                "bundle_id": bundleValue(bundleID),
            ]),
            luaArgs: [
                .number(Double(id.raw)),
                .string(app),
                .string(from?.raw ?? ""),
                .string(to.raw),
                .string(bundleID ?? ""),
            ]
        )
    }

    /// `app` and `space` come from `AppliedEffects` — the
    /// coordinator captures them as it removes the window, so
    /// the payload reports
    /// the space the window actually disappeared from, not
    /// whichever space happens to be active. `reason` tells a
    /// real close from a minimize or a native-switch vanish
    /// (#40; the retired `window_minimized` event lives on as
    /// `reason: minimized`).
    func emitWindowDestroyed(
        _ id: WindowID,
        app: String?,
        bundleID: String?,
        space: SpaceID?,
        reason: WindowGoneReason
    ) {
        bus.emit(
            .windowDestroyed,
            data: .object([
                "window_id": .number(Double(id.raw)),
                "app": .string(app ?? ""),
                "space_id": space.map { .string($0.raw) }
                    ?? .null,
                "reason": .string(reason.rawValue),
                "bundle_id": bundleValue(bundleID),
            ]),
            luaArgs: [
                .number(Double(id.raw)),
                .string(app ?? ""),
                .string(space?.raw ?? ""),
                .string(reason.rawValue),
                .string(bundleID ?? ""),
            ]
        )
    }
}
