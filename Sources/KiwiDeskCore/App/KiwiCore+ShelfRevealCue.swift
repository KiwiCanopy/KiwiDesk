import AppKit

/// The refusal a bar's shortcut draws where it cannot show the bar
/// (#761): a pill beside the shelf it names, so a press that does
/// nothing says why — the bar is already shown, or the layout
/// carries no App Bar.
extension KiwiCore {
    enum RevealRefusal: Equatable {
        case alwaysShown(ShelfBar)
        case noAppBarHere
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
            if flashRefusalPill(
                near: drawn.strip,
                edge: drawn.edge,
                text: text,
                symbol: symbol
            ) {
                soundRefusal()
            }
            return
        }
        guard let window = focusedWindowID,
            flashRefusalPill(window, text: text, symbol: symbol)
        else { return }
        soundRefusal()
    }

    /// The pill's sentence: a fact, the fix living on the shortcut
    /// row in Settings (ui-designer, #761).
    static func revealRefusalText(_ refusal: RevealRefusal) -> String {
        switch refusal {
        case .alwaysShown(.space):
            L(
                "shelf.reveal_refused.space_always",
                "Space Bar is set to Always"
            )
        case .alwaysShown(.app):
            L(
                "shelf.reveal_refused.app_always",
                "App Bar is set to Always"
            )
        case .noAppBarHere:
            L(
                "shelf.reveal_refused.no_app_bar",
                "No App Bar in this layout"
            )
        }
    }
}

extension KiwiCore.RevealRefusal {
    /// The bar whose shelf the pill stands beside.
    var bar: ShelfBar {
        switch self {
        case .alwaysShown(let bar): bar
        case .noAppBarHere: .space
        }
    }
}
