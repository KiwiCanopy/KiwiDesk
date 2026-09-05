import Foundation

/// The one place a refusal becomes something a person sees
/// (#1258). Glyph, sentence and the second pill a paired
/// refusal wears all derive from the CASE — never from each
/// other, and never from the wording (#96: Core returns
/// structure, and this is the boundary where it stops being
/// structure).
///
/// Before this they were three decisions in three places: the
/// glyph here, the sentence inside whichever `refuse*` function
/// a call site chose, and which function that was at the call
/// site. A wrong sentence was therefore a wrong CALL rather
/// than a wrong value, invisible to every test — which is how
/// two false sentences shipped in one change set.
extension ResizeRefusal {
    /// The pill's leading glyph, in one exhaustive switch so a
    /// new refusal cannot ship wearing another one's symbol
    /// (#1260, `ResizeRefusalSymbolTests`).
    ///
    /// The rule the mapping encodes: **an arrow means a resize
    /// stopped, a non-arrow means there is no resize here.** It
    /// is the pill's only non-verbal channel and the only part
    /// that survives truncation, so it carries the
    /// impossible/blocked split the sentence spells out —
    /// readable with no legend, and free, since the slot is
    /// drawn on every pill either way.
    ///
    /// `.neighborMinimum` keeps the SHRINK arrow deliberately:
    /// a shrink whose group floor is carried by a mate routes
    /// here too, so a direction-derived glyph would draw a grow
    /// arrow on a shrink gesture.
    ///
    /// Every name here is SF Symbols 1.0. That is a
    /// requirement, not trivia: a symbol added after the macOS
    /// 14 deployment target resolves on a modern dev host and
    /// renders nil on the target, leaving an empty gutter and
    /// no error.
    var pillSymbol: String {
        switch self {
        case .ownMinimum, .neighborMinimum:
            "arrow.down.right.and.arrow.up.left"
        case .ownMaximum:
            "arrow.up.left.and.arrow.down.right"
        case .noAxisHere, .layoutHasNoResize, .nothingToDivide:
            "nosign"
        }
    }

    /// The sentence the pill draws on `window`. `@MainActor`
    /// because `L()` is — Core draws its own overlays and this
    /// is one of them (core-boundaries.md's allow-list).
    @MainActor
    var pillText: String {
        switch self {
        case .ownMinimum:
            L(
                "resize.min_size_reached",
                "Minimum window size reached"
            )
        case .neighborMinimum:
            L(
                "resize.neighbor_min_size",
                "Neighboring window at its minimum size"
            )
        case .ownMaximum(_, _, let atBoundary):
            atBoundary
                ? L("resize.boundary_reached", "No room left to grow")
                : L(
                    "resize.max_size_reached",
                    "Maximum window size reached"
                )
        case .noAxisHere(_, let axis):
            axis == "y"
                ? L(
                    "resize.no_height_here",
                    "This zone divides widths, not heights"
                )
                : L(
                    "resize.no_width_here",
                    "This zone divides heights, not widths"
                )
        case .nothingToDivide(_, let otherAxisDivides):
            otherAxisDivides
                ? L(
                    "resize.divide_other_axis",
                    "Nothing to divide here — try the other axis"
                )
                : L(
                    "resize.nothing_to_divide",
                    "This zone has nothing to divide"
                )
        case .layoutHasNoResize:
            L(
                "resize.layout_has_none",
                "This layout has no resizing"
            )
        }
    }

    /// The window wearing a SECOND pill, and what it says. One
    /// refusal, two ends: the trier explains why nothing moved
    /// and the blocker marks itself at its minimum (owner
    /// ruling 2026-08-22; #435's anchor rule still holds — the
    /// window that cannot move is marked). One pill on the
    /// blocker alone read absurd, since from its own
    /// perspective IT reached the minimum, not a neighbor.
    ///
    /// The second pill draws but does NOT sound: one refusal
    /// wearing two pills that beeps twice reads as two failures
    /// (#1255), and it carries the SAME glyph, which is what
    /// makes it one refusal worn twice rather than two (#1260).
    @MainActor
    var secondPill: (window: WindowID, text: String)? {
        switch self {
        case .neighborMinimum(let anchor, _, let axis):
            let mark = ResizeRefusal.ownMinimum(
                anchor,
                axis: axis
            )
            return (anchor, mark.pillText)
        default:
            return nil
        }
    }
}
