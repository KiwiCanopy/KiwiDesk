import CoreGraphics
import Foundation

/// What the tour's Spaces step draws for a choice (#3294): each
/// screen's Spaces, left to right, read off the same composition the
/// apply makes, so the picture never places a Space the apply does
/// not.
extension KiwiCore {
    /// One Space on a tour card.
    public struct TourSpace: Equatable, Sendable {
        public let id: SpaceID
        public let mode: LayoutMode
    }

    /// One screen's column on the tour's Spaces step.
    public struct TourColumn: Equatable, Sendable {
        public let display: Display
        public let spaces: [TourSpace]
    }

    /// `layout`'s Spaces per screen as its apply would place them,
    /// or the live arrangement's Spaces where `layout` is nil; screens left to
    /// right, a screen with no Space left out.
    public func tourPlan(for layout: StandardLayout?) -> [TourColumn] {
        let displays = state.workspaces.allDisplays.sorted {
            $0.frame.minX < $1.frame.minX
        }
        let main = PositionalDisplays.ordered(
            displays,
            mainID: PositionalDisplays.liveMainID
        ).first?.id
        var placed: [(TourSpace, DisplayID?)] = []
        if let layout {
            guard layout.plans(forScreens: displays.count),
                let composed = ProfileComposition.compose(
                    layout: layout,
                    displays: displays,
                    mainID: PositionalDisplays.liveMainID
                )
            else { return [] }
            placed = composed.spaces.map { id in
                (
                    TourSpace(id: id, mode: composed.spaceModes[id] ?? .bsp),
                    composed.assignment[id] ?? main
                )
            }
        } else {
            // The arrangement a replace would replace: held and
            // temporary Spaces are no part of it (#1507, #1790).
            let workspaces = state.workspaces
            placed = capturedSpaces.map {
                (
                    TourSpace(id: $0.id, mode: $0.mode),
                    workspaces.display(of: $0.id) ?? main
                )
            }
        }
        return displays.compactMap { display in
            let spaces = placed.filter { $0.1 == display.id }.map(\.0)
            guard !spaces.isEmpty else { return nil }
            return TourColumn(display: display, spaces: spaces)
        }
    }

    /// Where a composition puts its Spaces on the live screens:
    /// the main screen's take the Main role, every other is pinned
    /// to its screen's fingerprint.
    func composedPlacement(
        _ composed: ProfileComposition.Composed
    ) -> (pins: [SpaceID: String], mains: [SpaceID]) {
        let ordered = PositionalDisplays.ordered(
            state.workspaces.allDisplays,
            mainID: PositionalDisplays.liveMainID
        )
        var pins: [SpaceID: String] = [:]
        var mains: [SpaceID] = []
        for space in composed.spaces {
            let assigned = composed.assignment[space]
            if assigned == ordered.first?.id || assigned == nil {
                mains.append(space)
            } else if let display = ordered.first(where: {
                $0.id == assigned
            }) {
                pins[space] = display.fingerprint
            }
        }
        return (pins, mains)
    }
}
