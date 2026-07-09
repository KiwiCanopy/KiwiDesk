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
            ]),
            luaArgs: [
                .number(Double(id.raw)),
                .string(window?.appName ?? ""),
            ]
        )
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
    /// reflects app_rules / spawn placement.
    func emitWindowCreated(_ window: ManagedWindow) {
        let space = state.workspaces.space(of: window.id)
        bus.emit(
            .windowCreated,
            data: .object([
                "window_id": .number(Double(window.id.raw)),
                "app": .string(window.appName),
                "space_id": space.map { .string($0.raw) }
                    ?? .null,
            ]),
            luaArgs: [
                .number(Double(window.id.raw)),
                .string(window.appName),
                .string(space?.raw ?? ""),
            ]
        )
    }

    func emitWindowDestroyed(
        _ id: WindowID,
        app: String?,
        space: SpaceID?
    ) {
        emitWindowGone(.windowDestroyed, id, app, space)
    }

    func emitWindowMinimized(
        _ id: WindowID,
        app: String?,
        space: SpaceID?
    ) {
        emitWindowGone(.windowMinimized, id, app, space)
    }

    /// Fires on an explicit single-window move
    /// (`move_to_space`); bulk reassignments
    /// (snapshot restore, profile load) stay silent.
    func emitWindowMovedToSpace(
        _ id: WindowID,
        app: String,
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
            ]),
            luaArgs: [
                .number(Double(id.raw)),
                .string(app),
                .string(from?.raw ?? ""),
                .string(to.raw),
            ]
        )
    }

    /// `app` and `space` are captured by handle() before
    /// state.apply removes the window — the payload reports
    /// the space the window actually disappeared from, not
    /// whichever space happens to be active.
    private func emitWindowGone(
        _ event: KiwiNotification,
        _ id: WindowID,
        _ app: String?,
        _ space: SpaceID?
    ) {
        bus.emit(
            event,
            data: .object([
                "window_id": .number(Double(id.raw)),
                "app": .string(app ?? ""),
                "space_id": space.map { .string($0.raw) }
                    ?? .null,
            ]),
            luaArgs: [
                .number(Double(id.raw)),
                .string(app ?? ""),
                .string(space?.raw ?? ""),
            ]
        )
    }
}
