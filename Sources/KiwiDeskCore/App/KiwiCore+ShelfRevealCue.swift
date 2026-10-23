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

    /// Draws `refusal`'s pill beside the shelf on `display`, else on
    /// the focused window.
    func cueRevealRefusal(_ refusal: RevealRefusal, display: DisplayID) {
        let text = Self.revealRefusalText(refusal)
        let symbol = "eye.slash"
        if let drawn = shelves.drawnStrip(
            on: display,
            preferring: refusal.bar
        ) {
            soundIfDrawn(
                flashRefusalPill(
                    near: drawn.strip,
                    on: display,
                    edge: drawn.edge,
                    text: text,
                    symbol: symbol,
                    announce: false
                )
            )
        } else if let window = focusedWindowID {
            soundIfDrawn(
                flashRefusalPill(
                    window,
                    text: text,
                    symbol: symbol,
                    announce: false
                )
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
