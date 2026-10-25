import CoreGraphics
import Foundation

/// `list_windows [space]` (#2492): where every tracked window sits,
/// in AX coordinates (top-left origin, y grows down), from the one
/// placement read the App Bar's verdict takes — a tile's placed
/// frame, a float's target in flight or its last report. No app is
/// asked. Joins `get_state` by `id`, which keeps the title.
extension KiwiCore {
    /// Where one listed window is drawn, or nil parts where it is
    /// not.
    private struct ListedSite {
        let home: SpaceID?
        let drawn: SpaceID?
        let display: DisplayID?
        let isShown: Bool
        let frame: CGRect?
    }

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
        let listed = listedWindowOrder().compactMap { id in
            state.windows[id].map { window in
                (
                    window,
                    site(of: window, shown: shown, placement: placements[id])
                )
            }
        }
        let ranks = stackingRanks(listed.map { ($0.0.id, $0.1) })
        let windows = listed.compactMap { window, site -> JSONValue? in
            if let filter, site.home != filter { return nil }
            return listedWindow(
                window,
                site: site,
                placement: placements[window.id],
                z: ranks[window.id]
            )
        }
        return .ok(.array(windows))
    }

    /// Each on-screen window's stacking rank among the tracked
    /// windows on the screen its `display` names, 0 frontmost
    /// (#2546). A compositor read where the App Bar takes issued
    /// frames (#1925): this verb runs on demand, never per switch.
    private func stackingRanks(
        _ sites: [(WindowID, ListedSite)]
    ) -> [WindowID: Int] {
        let onScreen = sites.compactMap { id, site in
            site.frame == nil ? nil : site.display.map { (id, $0) }
        }
        guard !onScreen.isEmpty else { return [:] }
        let display = Dictionary(onScreen, uniquingKeysWith: { a, _ in a })
        var next: [DisplayID: Int] = [:]
        var ranks: [WindowID: Int] = [:]
        for listed in frontStack() {
            let id = WindowID(listed.number)
            guard ranks[id] == nil, let screen = display[id] else {
                continue
            }
            ranks[id] = next[screen, default: 0]
            next[screen, default: 0] += 1
        }
        return ranks
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
                state.renderSpace(of: $0) == id && !$0.isFullscreen
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

    private func site(
        of window: ManagedWindow,
        shown: Set<SpaceID>,
        placement: WindowPlacement?
    ) -> ListedSite {
        let drawn = state.renderSpace(of: window)
        let isShown = drawn.map(shown.contains) ?? false
        // A parked frame — an unshown Space's, a monocle park
        // (#881) — is no place the window lives (#2492).
        let frame =
            isShown
            ? (window.isFullscreen ? window.frame : placement?.frame)
                .flatMap { tiler.looksStashed($0) ? nil : $0 }
            : nil
        return ListedSite(
            home: state.workspaces.space(of: window.id),
            drawn: drawn,
            display: drawn.flatMap { state.workspaces.display(of: $0) },
            isShown: isShown,
            frame: frame
        )
    }

    private func listedWindow(
        _ window: ManagedWindow,
        site: ListedSite,
        placement: WindowPlacement?,
        z: Int?
    ) -> JSONValue {
        let id = window.id
        let index = site.home
            .flatMap { state.workspaces[$0]?.windows.firstIndex(of: id) }
        return .object([
            "id": .number(Double(id.raw)),
            "app": .string(window.appName),
            "pid": .number(Double(window.pid)),
            "space_id": site.home.map { .string($0.raw) } ?? .null,
            "index": index.map { .number(Double($0 + 1)) } ?? .null,
            "display": site.display.map { .number(Double($0.raw)) }
                ?? .null,
            "shown": .bool(site.isShown),
            "frame": site.frame.map(Self.json(rect:)) ?? .null,
            "z": z.map { .number(Double($0)) } ?? .null,
            "visibility": placement.map {
                Self.json(visibility: $0.visibility)
            } ?? .null,
            "floats": .bool(
                EffectiveFloat.applies(
                    isFloating: window.isFloating,
                    mode: site.drawn.flatMap { state.workspaces[$0]?.mode }
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
