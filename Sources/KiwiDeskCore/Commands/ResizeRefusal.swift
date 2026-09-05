import Foundation

/// Which size limit refused (part of) an interactive resize
/// (#933) — the structure the cues render, and what the test
/// seam (`BorderManager.onResizeRefusal`) observes, since the
/// drawn cues are display-gated and invisible headless.
///
/// **A case carries everything the drawing decides from**
/// (#1258). It used to carry the window alone, with the axis
/// and the wording chosen inside whichever `refuse*` function a
/// call site happened to pick — so one refusal's identity lived
/// in three places, the sentence was unobservable at the seam,
/// and a call site that chose wrongly redded nothing. Five
/// review rounds each found either a site that cued nothing or
/// a site whose sentence was false; both are decisions this
/// type can now hold, and a test can read.
enum ResizeRefusal: Equatable {
    /// A shrink stopped at the resized window's own effective
    /// minimum (`min_window_size`, or its learned app bound).
    case ownMinimum(WindowID, axis: String)
    /// A grow stopped where `anchor` — a neighboring window —
    /// would drop below ITS effective minimum.
    case neighborMinimum(
        anchor: WindowID,
        focused: WindowID,
        axis: String
    )
    /// A grow stopped at the resized window's own learned
    /// app-enforced maximum (#1055) — the app refuses to get
    /// bigger, so growing the slot further only overshoots — or
    /// against the region a float may occupy (#1091), which the
    /// wording tells apart and no consumer acts on.
    case ownMaximum(WindowID, axis: String, atBoundary: Bool)
    /// The zone the focused window sits in has no parameter on
    /// the asked axis at all (#1255) — a horizontal master zone
    /// divides widths, so a height press has nothing to move.
    /// Not a limit reached: a limit that does not exist.
    case noAxisHere(WindowID, axis: String)
    /// The group the asked axis divides holds ONE member
    /// (#1258) — a stack column, a track, a track set, a bsp
    /// space of one, a pile that answers to no ratio. The
    /// parameter exists and there is nothing to move it
    /// against, which is why this is not `noAxisHere`: that one
    /// says the OTHER axis divides, and here the count is the
    /// reason rather than the arrangement.
    ///
    /// `otherAxisDivides` rides the case rather than the
    /// renderer's argument list because a caller answers it
    /// from its own partition, and five callers answering
    /// invisibly is how a sentence pointing at an axis that
    /// divides nothing shipped twice. Here a test reads the
    /// verdict.
    case nothingToDivide(WindowID, otherAxisDivides: Bool)
    /// The space's layout has no resizing at all (#1255) —
    /// monocle, grid and floating. The most reachable refusal
    /// there is, and until now the one cued by sound alone.
    case layoutHasNoResize(WindowID)
}

extension ResizeRefusal {
    /// The window the gesture was about — the one that bumps,
    /// and the one a pill lands on. For `neighborMinimum` that
    /// is the TRIER; its anchor wears a second pill of its own
    /// (#435: the window that cannot move is marked, and the
    /// trier is told why nothing happened).
    var window: WindowID {
        switch self {
        case .ownMinimum(let id, _), .ownMaximum(let id, _, _),
            .noAxisHere(let id, _), .nothingToDivide(let id, _),
            .layoutHasNoResize(let id):
            id
        case .neighborMinimum(_, let focused, _):
            focused
        }
    }

    /// The axis the gesture asked for, where the refusal knows
    /// it. `layoutHasNoResize` and `nothingToDivide` do not: the
    /// first refuses every axis and the second names none.
    var axis: String? {
        switch self {
        case .ownMinimum(_, let axis), .ownMaximum(_, let axis, _),
            .noAxisHere(_, let axis):
            axis
        case .neighborMinimum(_, _, let axis):
            axis
        case .nothingToDivide, .layoutHasNoResize:
            nil
        }
    }

    /// Whether the focus ring rubber-bands (#436). A limit
    /// REACHED bumps — the gesture hit a wall — while a limit
    /// that does not exist has no wall to bounce off.
    var bumps: Bool {
        switch self {
        case .ownMinimum, .ownMaximum, .neighborMinimum: true
        case .noAxisHere, .nothingToDivide, .layoutHasNoResize:
            false
        }
    }
}
