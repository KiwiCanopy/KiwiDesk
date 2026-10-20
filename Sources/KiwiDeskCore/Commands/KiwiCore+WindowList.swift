import CoreGraphics
import Foundation

/// `list_windows [space]` (#2492): where every tracked window sits,
/// in AX coordinates (top-left origin, y grows down), from the one
/// placement read the App Bar's verdict takes — a tile's placed
/// frame, a float's target in flight or its last report. No app is
/// asked. Joins `get_state` by `id`, which keeps the app and title.
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
        let shown = shownSpaceIDs()
        let placements = shownPlacements(shown)
        let windows = listedWindowOrder().compactMap { id in
            state.windows[id].flatMap { window -> JSONValue? in
                let home = state.workspaces.space(of: id)
                if let filter, home != filter { return nil }
                return listedWindow(
                    window,
                    home: home,
                    shown: shown,
                    placement: placements[id]
                )
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

    /// Every window drawn on a shown Space, through the one
    /// placement read. A floating-mode Space judges every member as
    /// a float; a native-fullscreen window, on a macOS Space of its
    /// own (#670), is judged on none.
    private func shownPlacements(
        _ shown: Set<SpaceID>
    ) -> [WindowID: WindowPlacement] {
        var placements: [WindowID: WindowPlacement] = [:]
        for id in shown {
            guard let space = state.workspaces[id] else { continue }
            let drawn = state.windows.all.filter {
                renderSpace(of: $0) == id && !$0.isFullscreen
            }
            let tiled = Set(state.effectiveTiledMembers(of: space))
            let floats = drawn.map(\.id).filter {
                space.mode == .floating || !tiled.contains($0)
            }
            placements.merge(
                windowPlacements(of: space, floats: floats),
                uniquingKeysWith: { first, _ in first }
            )
        }
        return placements
    }

    /// The Space a window draws on: a sticky one's render Space,
    /// else its own.
    func renderSpace(of window: ManagedWindow) -> SpaceID? {
        state.stickyRenderSpace(of: window)
            ?? state.workspaces.space(of: window.id)
    }

    private func listedWindow(
        _ window: ManagedWindow,
        home: SpaceID?,
        shown: Set<SpaceID>,
        placement: WindowPlacement?
    ) -> JSONValue {
        let id = window.id
        let drawn = renderSpace(of: window)
        let isShown = drawn.map(shown.contains) ?? false
        // A parked frame — an unshown Space's, a monocle park
        // (#881) — is no place the window lives (#2492).
        let frame =
            isShown
            ? (window.isFullscreen ? window.frame : placement?.frame)
                .flatMap { tiler.looksStashed($0) ? nil : $0 }
            : nil
        return .object([
            "id": .number(Double(id.raw)),
            "space_id": home.map { .string($0.raw) } ?? .null,
            "display": drawn.flatMap { state.workspaces.display(of: $0) }
                .map { .number(Double($0.raw)) } ?? .null,
            "shown": .bool(isShown),
            "frame": frame.map(Self.json(rect:)) ?? .null,
            "visibility": placement.map {
                Self.json(visibility: $0.visibility)
            } ?? .null,
            "floats": .bool(
                EffectiveFloat.applies(
                    isFloating: window.isFloating,
                    mode: drawn.flatMap { state.workspaces[$0]?.mode }
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
