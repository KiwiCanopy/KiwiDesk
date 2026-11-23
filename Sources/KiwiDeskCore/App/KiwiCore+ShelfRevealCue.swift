import AppKit

/// The refusal a bar's shortcut draws where it cannot show the bar
/// (#761): a pill beside the shelf it names, so a press that does
/// nothing says why — the bar is already shown, the layout carries
/// no App Bar, the bar has nothing to show (#2567), or a window
/// fills the screen (#2775).
extension KiwiCore {
    enum RevealRefusal: Equatable {
        case alwaysShown(ShelfBar)
        /// Set to Auto, but reading Always beside an Always bar on
        /// its edge.
        case shownBesideAlways(ShelfBar)
        case noAppBarHere
        /// Nothing to show here: an App Bar on a Space with no
        /// window, a Space Bar with no Space (#2567).
        case nothingToShow(ShelfBar)
        /// The shelf stands down for what is in front: a maximized
        /// window, a full-screen one or a presentation (#2775).
        case standsDown(ShelfBar)
    }

    /// Draws `refusal`'s pill where its bar sits, where the user
    /// looks on pressing its key (owner, #2567): beside the shelf
    /// carrying that bar, else at that bar's own edge of the screen —
    /// never on a window, never beside the other bar's shelf.
    func cueRevealRefusal(
        _ refusal: RevealRefusal,
        placement: PlacementID
    ) {
        let display = placement.display
        guard let place = refusalPlace(of: refusal.bar, on: placement)
        else { return }
        soundIfDrawn(
            flashRefusalPill(
                near: place.strip,
                on: display,
                edge: place.edge,
                text: Self.revealRefusalText(refusal),
                symbol: "eye.slash",
                announce: false
            )
        )
    }

    /// The strip a refusal's pill stands beside, AX coordinates: the
    /// shelf of `placement` carrying `bar`, else a zero-depth strip
    /// along `bar`'s edge of the area's frame (#3517).
    func refusalPlace(
        of bar: ShelfBar,
        on placement: PlacementID
    ) -> (strip: CGRect, edge: AppBarEdge)? {
        if let shelf = shelves.drawnStrip(on: placement, carrying: bar) {
            return shelf
        }
        guard let screen = screen(for: placement.display) else { return nil }
        let settings = self.settings(on: placement)
        let edge =
            bar == .app
            ? settings.appBarStyle.edge : settings.spaceBarStyle.edge
        let area = state.workspaces[placement: placement]
        return (refusalStrip(of: screen, edge: edge, in: area), edge)
    }

    /// A zero-depth strip along `edge` of `screen`'s visible frame —
    /// cut to `area`'s frame on a split screen (#3517) — AX
    /// coordinates: where a pill stands with no shelf beside it.
    func refusalStrip(
        of screen: NSScreen,
        edge: AppBarEdge,
        in area: Placement? = nil
    ) -> CGRect {
        // Chrome is drawn on a REAL screen (`VisibleBoundsRoutingTests`).
        let whole = GeometryUtils.axVisibleFrame(of: screen)
        let visible =
            area.map { shelfFrame(of: $0, visible: whole, on: screen) }
            ?? whole
        switch edge {
        case .top:
            return CGRect(
                x: visible.minX,
                y: visible.minY,
                width: visible.width,
                height: 0
            )
        case .bottom:
            return CGRect(
                x: visible.minX,
                y: visible.maxY,
                width: visible.width,
                height: 0
            )
        case .left:
            return CGRect(
                x: visible.minX,
                y: visible.minY,
                width: 0,
                height: visible.height
            )
        case .right:
            return CGRect(
                x: visible.maxX,
                y: visible.minY,
                width: 0,
                height: visible.height
            )
        }
    }

    /// The pill's sentence: a fact, the fix living on the shortcut
    /// row in Settings (ui-designer, #761).
    static func revealRefusalText(_ refusal: RevealRefusal) -> String {
        switch refusal {
        case .alwaysShown(.space):
            L(
                "shelf.reveal_refused.space_set",
                "Space Bar is set to %1$@",
                L("bar.visibility.always", "Always")
            )
        case .alwaysShown(.app):
            L(
                "shelf.reveal_refused.app_set",
                "App Bar is set to %1$@",
                L("bar.visibility.always", "Always")
            )
        case .shownBesideAlways(.space):
            L(
                "shelf.reveal_refused.space_beside",
                "Space Bar stays shown beside the App Bar"
            )
        case .shownBesideAlways(.app):
            L(
                "shelf.reveal_refused.app_beside",
                "App Bar stays shown beside the Space Bar"
            )
        case .noAppBarHere:
            L(
                "shelf.reveal_refused.no_app_bar",
                "No App Bar in this layout"
            )
        case .nothingToShow(.app):
            L(
                "shelf.reveal_refused.app_empty",
                "No windows for the App Bar here"
            )
        case .nothingToShow(.space):
            L(
                "shelf.reveal_refused.space_empty",
                "No Spaces for the Space Bar here"
            )
        case .standsDown:
            L(
                "shelf.reveal_refused.stands_down",
                "Bars stay hidden while a window fills the screen"
            )
        }
    }
}

extension KiwiCore.RevealRefusal {
    /// The bar whose shelf the pill stands beside.
    var bar: ShelfBar {
        switch self {
        case .alwaysShown(let bar), .shownBesideAlways(let bar),
            .nothingToShow(let bar), .standsDown(let bar):
            bar
        case .noAppBarHere: .space
        }
    }
}
