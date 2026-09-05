import Foundation

/// Which size limit refused (part of) an interactive resize
/// (#933) — the structure the cues render, and what the test
/// seam (`BorderManager.onResizeRefusal`) observes, since the
/// drawn cues are display-gated and invisible headless.
enum ResizeRefusal: Equatable {
    /// A shrink stopped at the resized window's own effective
    /// minimum (`min_window_size`, or its learned app bound).
    case ownMinimum(WindowID)
    /// A grow stopped where `anchor` — a neighboring window —
    /// would drop below ITS effective minimum.
    case neighborMinimum(anchor: WindowID, focused: WindowID)
    /// A grow stopped at the resized window's own learned
    /// app-enforced maximum (#1055) — the app refuses to get
    /// bigger, so growing the slot further only overshoots.
    case ownMaximum(WindowID)
    /// The zone the focused window sits in has no parameter on
    /// the asked axis at all (#1255) — a horizontal master zone
    /// divides widths, so a height press has nothing to move.
    /// Not a limit reached: a limit that does not exist.
    case noAxisHere(WindowID)
    /// The space's layout has no resizing at all (#1255) —
    /// monocle, grid and floating. The most reachable refusal
    /// there is, and until now the one cued by sound alone.
    case layoutHasNoResize(WindowID)
}

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
    /// Read off the CASE and never off the text (#96 — Core
    /// returns structure, the GUI narrates). `.neighborMinimum`
    /// keeps the SHRINK arrow deliberately: a shrink whose
    /// group floor is carried by a mate routes through
    /// `refuseGrowAtNeighborMinimum`, so a direction-derived
    /// glyph would draw a grow arrow on a shrink gesture.
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
        case .noAxisHere, .layoutHasNoResize:
            "nosign"
        }
    }
}
