import AppKit
import CoreGraphics

/// Screen areas in layout (#3517): split from
/// `TilingEngine+Layout.swift` at the §2.1 ceiling.
extension TilingEngine {
    /// The neighbours of `region` on the screen `visible`: the
    /// screen's own scan where it is not split; an area's edge flags
    /// over every area and unsplit screen, its park over the
    /// physical screens alone (#3517 ruling 31).
    func neighbors(
        around region: CGRect,
        on visible: CGRect
    ) -> ScreenNeighbors {
        let screens = allScreenBounds()
        let areas = splitAreaBounds()
        guard !areas.isEmpty else {
            return ScreenNeighbors.detect(around: visible, among: screens)
        }
        let whole = screens.filter { screen in
            !areas.contains { $0.intersects(screen) }
        }
        return ScreenNeighbors.detect(
            around: region,
            among: whole + areas,
            parkingOn: visible,
            among: screens
        )
    }

    /// Every space shown in place this pass paired with the
    /// screen it lays out on: one entry per placement — each area
    /// of a split screen, each unsplit screen whole. Falls back to
    /// the focused `activeSpace` on the main screen when no
    /// displays are tracked yet (unit tests, early boot) — the
    /// single-monitor path. The focused active space is always
    /// included even if its display is momentarily untracked, so
    /// its windows are never left unplaced.
    func visiblePlacements(
        state: StateCoordinator
    ) -> [(space: Space, screen: NSScreen)] {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else {
            guard
                let id = state.workspaces.activeSpace,
                let space = state.workspaces[id],
                let screen = ScreenList.mainOrFirst
            else { return [] }
            return [(space, screen)]
        }
        let fallback = ScreenList.mainOrFirst
        // Keyed by physical screen (frame origin — stable across
        // the fresh `NSScreen` instances `NSScreen.screens` may
        // hand back) and area, so each area of a screen hosts
        // exactly ONE space (#3517): two placements falling back to
        // `main`, or a focused active space whose display is
        // untracked, cannot double-place one area — the focused
        // active space, written last, wins its area.
        var byScreen: [String: (space: Space, screen: NSScreen)] = [:]
        func key(_ s: NSScreen, _ area: Int) -> String {
            "\(s.frame.origin.x),\(s.frame.origin.y)#\(area)"
        }
        let placements = state.workspaces.allPlacements
        for placement in placements {
            guard
                let id = state.workspaces.activeSpace(on: placement.id),
                let space = state.workspaces[id],
                let screen = Self.screen(for: placement.display)
                    ?? fallback
            else { continue }
            byScreen[key(screen, placement.area.id)] = (space, screen)
        }
        if let id = state.workspaces.activeSpace,
            let space = state.workspaces[id],
            let screen = Self.screen(for: id, in: state)
        {
            let area = state.workspaces.placement(of: id)?.area ?? 0
            byScreen[key(screen, area)] = (space, screen)
        }
        return Array(byScreen.values)
    }
}
