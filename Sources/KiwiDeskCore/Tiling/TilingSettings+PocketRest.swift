import CoreGraphics

/// How the pocket stands at rest on its edge (#2678, #2784).
public enum PocketRest: Sendable, Equatable {
    /// A section of the bars drawn on its edge.
    case section
    /// The kiwi handle, on an edge that draws no bar at rest.
    case handle
    /// The whole bare mark, on an edge no bar shows while the bars
    /// read Always.
    case mark
}

extension TilingSettings {
    /// How the pocket stands at rest on `screen` in `mode`: a section
    /// where its edge draws a bar at rest, the handle where that
    /// edge's bars hide; on an edge no bar shows it follows the bars'
    /// Show, the more present of the two (owner, #2784 ▸ 8). The
    /// at-rest answer from stored settings: the reservation and the
    /// whole mark read it, while a live section stands where the
    /// bar pass draws a bar (`PocketPlateOverlay.slots`).
    public func pocketRest(
        in mode: LayoutMode,
        on screen: String?
    ) -> PocketRest {
        let settings = onScreen(screen)
        let app = appBarVisibility(in: mode)
        let edge = settings.barEdges(
            space: spaceBarStyle.visibility,
            app: app
        ).first { $0.edge == settings.kiwishelf.pocketEdge }
        if let edge {
            return edge.drawsNothingAtRest ? .handle : .section
        }
        let show = [spaceBarStyle.visibility, app]
            .compactMap { $0 }
            .max { $0.presence < $1.presence }
        return show == .always ? .mark : .handle
    }

    /// The strip the pocket reserves at rest on `screen` in `mode`,
    /// nil where it reserves none: the handle's on an edge whose bars
    /// hide, the shelf's own where the whole mark stands (#2784). A
    /// section takes the bars' strip, and a bar's `reserve` off on
    /// that edge — on an edge no bar shows, both bars' — reserves
    /// nothing (#1524).
    func pocketReservation(
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
        guard reserves else { return nil }
        switch pocketRest(in: mode, on: screen) {
        case .section: return nil
        case .handle: return (pocketEdge, kiwishelf.pocketHandleReservation)
        case .mark: return (pocketEdge, kiwishelf.reservation)
        }
    }
}
