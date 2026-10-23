import AppKit

/// The refusal a bar's shortcut draws where it cannot show the bar
/// (#761): a pill beside the shelf it names, so a press that does
/// nothing says why — the bar is already shown, the layout carries
/// no App Bar, or the bar has nothing to show (#2567).
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
    }

    /// Draws `refusal`'s pill where its bar sits, where the user
    /// looks on pressing its key (owner, #2567): beside the shelf
    /// carrying that bar, else at that bar's own edge of the screen —
    /// never on a window, never beside the other bar's shelf.
    func cueRevealRefusal(_ refusal: RevealRefusal, display: DisplayID) {
        guard let place = refusalPlace(of: refusal.bar, on: display)
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
    /// shelf carrying `bar`, else a zero-depth strip along `bar`'s
    /// edge of the screen's visible frame.
    func refusalPlace(
        of bar: ShelfBar,
        on display: DisplayID
    ) -> (strip: CGRect, edge: AppBarEdge)? {
        if let shelf = shelves.drawnStrip(on: display, carrying: bar) {
            return shelf
        }
        guard let screen = screen(for: display) else { return nil }
        let settings = tiler.settings
        let fingerprint = screenFingerprint(of: display)
        let edge =
            bar == .app
            ? settings.appBarStyle.edge(on: fingerprint)
            : settings.spaceBarStyle.edge(on: fingerprint)
        // Chrome is drawn on a REAL screen (`VisibleBoundsRoutingTests`).
        let visible = GeometryUtils.axVisibleFrame(of: screen)
        let strip: CGRect
        switch edge {
        case .top:
            strip = CGRect(
                x: visible.minX,
                y: visible.minY,
                width: visible.width,
                height: 0
            )
        case .bottom:
            strip = CGRect(
                x: visible.minX,
                y: visible.maxY,
                width: visible.width,
                height: 0
            )
        case .left:
            strip = CGRect(
                x: visible.minX,
                y: visible.minY,
                width: 0,
                height: visible.height
            )
        case .right:
            strip = CGRect(
                x: visible.maxX,
                y: visible.minY,
                width: 0,
                height: visible.height
            )
        }
        return (strip, edge)
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
        }
    }
}

extension KiwiCore.RevealRefusal {
    /// The bar whose shelf the pill stands beside.
    var bar: ShelfBar {
        switch self {
        case .alwaysShown(let bar), .shownBesideAlways(let bar),
            .nothingToShow(let bar):
            bar
        case .noAppBarHere: .space
        }
    }
}
