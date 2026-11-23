import Foundation

/// The Desktops side on a split screen (#3572 ruling 2): each
/// Desktop's Space lines grouped by area, in the areas' reading
/// order, each area's Spaces in creation order. Every Desktop of a
/// screen lists the screen's live Spaces, so one grouping serves
/// all of its cards.
extension KiwiCore {
    /// A screen's Spaces in the order the overview lists them, and
    /// the area groups over them.
    struct OverviewGrouping {
        let spaces: [SpaceID]
        let areas: [DesktopOverview.Area]
    }

    /// `display`'s grouping; `here` is the area KiwiHub opened
    /// over. An unsplit screen lists its Spaces in one run.
    func overviewGrouping(
        on display: DisplayID,
        here: PlacementID?
    ) -> OverviewGrouping {
        let placements = state.workspaces.placements(of: display)
        guard placements.count > 1 else {
            return OverviewGrouping(
                spaces: state.workspaces.spaces(on: display),
                areas: []
            )
        }
        let positions = ScreenSplit(areas: placements.map(\.area))
            .positions
        var spaces: [SpaceID] = []
        var areas: [DesktopOverview.Area] = []
        for placement in placements {
            let start = spaces.count
            spaces += state.workspaces.spaces(on: placement.id)
            areas.append(
                DesktopOverview.Area(
                    key: placement.key,
                    name: placement.area.name,
                    position: positions[placement.area.id],
                    isHere: placement.id == here,
                    lines: start..<spaces.count
                )
            )
        }
        return OverviewGrouping(spaces: spaces, areas: areas)
    }

    /// The Spaces a hidden Desktop returns to: its cursor's, and on
    /// a split screen each area's filed one (#3517 ruling 17).
    func returningSpaces(
        of native: SkyLight.SpaceID,
        in snapshot: DesktopSnapshot
    ) -> Set<SpaceID> {
        let cursor = rememberedVirtualSpace(of: native, in: snapshot)
        let areas = rememberedAreaSpaces(of: native, in: snapshot)
        return Set(areas.values).union(cursor.map { [$0] } ?? [])
    }
}
