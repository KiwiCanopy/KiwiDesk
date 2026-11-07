import CoreGraphics

/// How the pocket stands at rest on its edge (#2678, #2784, #2978).
public enum PocketRest: Sendable, Equatable {
    /// A section of the bars drawn on its edge.
    case section
    /// The kiwi handle, on an edge that draws no bar at rest.
    case handle
    /// The whole bare mark, on an edge that draws no bar at rest
    /// while the pocket reads Always.
    case mark
}

extension TilingSettings {
    /// How the pocket stands at rest on `screen` in `mode`: a section
    /// where its edge draws a bar at rest, else its own Show decides,
    /// the whole mark under Always and the handle under Auto (#2978).
    /// The at-rest answer from stored settings, asked only while the
    /// pocket rests (not Hidden): the reservation and the whole mark
    /// read it, while a live section stands where the bar pass draws a
    /// bar (`PocketPlateOverlay.slots`).
    public func pocketRest(
        in mode: LayoutMode,
        on screen: String?
    ) -> PocketRest {
        let settings = onScreen(screen)
        let edge = settings.barEdges(
            space: spaceBarStyle.visibility,
            app: appBarVisibility(in: mode)
        ).first { $0.edge == settings.kiwishelf.pocketEdge }
        if let edge, !edge.drawsNothingAtRest { return .section }
        return kiwishelf.pocketVisibility == .always ? .mark : .handle
    }

    /// The strip the pocket reserves at rest on `screen` in `mode`,
    /// nil where it reserves none: the handle's on an edge whose bars
    /// hide, the shelf's own where the whole mark stands (#2784). A
    /// section takes the bars' strip, and a bar's `reserve` off on
    /// that edge — on an edge no bar shows, both bars' — reserves
    /// nothing (#1524).
    public func pocketReservation(
        in mode: LayoutMode,
        on screen: String?
    ) -> (edge: AppBarEdge, depth: CGFloat)? {
        let settings = onScreen(screen)
        let pocketEdge = settings.kiwishelf.pocketEdge
        let edge = settings.barEdges(
            space: spaceBarStyle.visibility,
            app: appBarVisibility(in: mode)
        ).first { $0.edge == pocketEdge }
        let hostsApp = appBarVisibility(in: mode) != nil
        let reserves =
            edge.map { !$0.reserving.isEmpty }
            ?? (spaceBarStyle.reserve || (hostsApp && appBarStyle.reserve))
        guard reserves, kiwishelf.pocketVisibility != .hidden else {
            return nil
        }
        switch pocketRest(in: mode, on: screen) {
        case .section: return nil
        case .handle: return (pocketEdge, kiwishelf.hiddenReservation)
        case .mark: return (pocketEdge, kiwishelf.reservation)
        }
    }
}

extension TilingSettings {
    /// Rests the pocket on the Space Bar's edge, the menu bar's, as
    /// the starter and every bundled look do (owner, 2026-10-30);
    /// the type default stays bottom.
    public mutating func restPocketWithTheSpaceBar() {
        kiwishelf.pocketEdge = spaceBarStyle.edge
    }
}
