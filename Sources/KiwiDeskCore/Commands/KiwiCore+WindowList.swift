import CoreGraphics
import Foundation

/// `list_windows [space]` (#2492): where every tracked window sits,
/// in AX coordinates (top-left origin, y grows down), read from the
/// frames KiwiDesk sent and never from the apps. Joins `get_state`
/// by `id`, which keeps the app and the title.
extension KiwiCore {
    func listWindows(_ args: [JSONValue]) -> CommandResponse {
        var filter: SpaceID?
        if let value = args.first, value != .null {
            guard let name = value.stringValue,
                state.workspaces[SpaceID(name)] != nil
            else {
                return .fail(
                    "unknown space: \(value.stringValue ?? "?")"
                )
            }
            filter = SpaceID(name)
        }
        let verdicts = shownVisibility()
        let windows = listedWindowOrder().compactMap { id in
            state.windows[id].flatMap { window -> JSONValue? in
                let home = state.workspaces.space(of: id)
                if let filter, home != filter { return nil }
                return listedWindow(window, home: home, verdicts)
            }
        }
        return .ok(.array(windows))
    }

    /// Spaces in order, each window in its row, then any tracked
    /// window no Space holds.
    private func listedWindowOrder() -> [WindowID] {
        let filed = state.workspaces.allSpaces.flatMap(\.windows)
        let seen = Set(filed)
        let rest = state.windows.all.map(\.id)
            .filter { !seen.contains($0) }
            .sorted { $0.raw < $1.raw }
        return filed + rest
    }

    /// The visibility of every window rendering on a Space a
    /// screen shows, through the one verdict the App Bar reads.
    private func shownVisibility() -> [WindowID: BarVisibility] {
        var verdicts: [WindowID: BarVisibility] = [:]
        for id in shownSpaces() {
            guard let space = state.workspaces[id] else { continue }
            let tiled = Set(state.effectiveTiledMembers(of: space))
            let others = state.windows.all
                .filter { renderSpace(of: $0) == id && !tiled.contains($0.id) }
                .map(\.id)
            verdicts.merge(
                appBarVisibility(of: space, floats: others),
                uniquingKeysWith: { first, _ in first }
            )
        }
        return verdicts
    }

    private func shownSpaces() -> Set<SpaceID> {
        Set(
            state.workspaces.allDisplays.compactMap {
                state.workspaces.currentSpace(on: $0.id)
            } + [state.workspaces.activeSpace].compactMap { $0 }
        )
    }

    /// The Space a window draws on: a sticky one's render Space,
    /// else its own.
    private func renderSpace(of window: ManagedWindow) -> SpaceID? {
        state.stickyRenderSpace(of: window)
            ?? state.workspaces.space(of: window.id)
    }

    private func listedWindow(
        _ window: ManagedWindow,
        home: SpaceID?,
        _ verdicts: [WindowID: BarVisibility]
    ) -> JSONValue {
        let id = window.id
        let drawn = renderSpace(of: window)
        let mode = home.flatMap { state.workspaces[$0]?.mode }
        // A window on a Space no screen shows sits parked: its
        // frame is the park, never where it lives (#2492).
        let verdict = verdicts[id]
        let frame = verdict.map { _ in
            tiler.commandedFrame(of: id) ?? window.frame
        }
        return .object([
            "id": .number(Double(id.raw)),
            "space_id": home.map { .string($0.raw) } ?? .null,
            "display": drawn.flatMap { state.workspaces.display(of: $0) }
                .map { .number(Double($0.raw)) } ?? .null,
            "shown": .bool(verdict != nil),
            "frame": frame.map(Self.json(rect:)) ?? .null,
            "visibility": verdict.map(Self.json(visibility:)) ?? .null,
            "floats": .bool(
                EffectiveFloat.applies(
                    isFloating: window.isFloating,
                    mode: mode
                )
            ),
            "focused": .bool(focusedWindowID == id),
            "fullscreen": .bool(window.isFullscreen),
        ])
    }

    static func json(rect: CGRect) -> JSONValue {
        .object([
            "x": .number(Double(rect.minX)),
            "y": .number(Double(rect.minY)),
            "width": .number(Double(rect.width)),
            "height": .number(Double(rect.height)),
        ])
    }

    private static func json(visibility: BarVisibility) -> JSONValue {
        switch visibility {
        case .visible: .string("visible")
        case .hidden: .string("hidden")
        case .partly(let side):
            .string(side.map { "partly_\($0)" } ?? "partly")
        }
    }
}
