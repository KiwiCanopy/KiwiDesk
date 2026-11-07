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
        case .noAxisHere, .layoutHasNoResize, .nothingToDivide,
            .gridNoOtherTrack, .windowIsFullscreen,
            .fullscreenCannotMove, .moveNeedsFloat:
            "nosign"
        case .moveAtBoundary(_, let direction):
            switch direction {
            case .left: "arrow.left"
            case .right: "arrow.right"
            case .up: "arrow.up"
            case .down: "arrow.down"
            }
        }
    }

    /// The sentence the pill draws on `window`. `@MainActor`
    /// because `L()` is — Core draws its own overlays and this
    /// is one of them (core-boundaries.md's allow-list).
    ///
    /// A limit the APP enforces names the app (#1261); the
    /// learned maximum is always the app's, since no configured
    /// maximum exists. Every sentence holds with no press
    /// behind it — the neighbour pair is drawn by a retile too
    /// (#934).
    @MainActor
    var pillText: String {
        switch self {
        case .ownMinimum(_, _, let appBound):
            appBound
                ? L(
                    "resize.app_min_reached",
                    "This app won't go smaller"
                )
                : L(
                    "resize.min_size_reached",
                    "Minimum window size reached"
                )
        case .neighborMinimum(_, _, _, let appBound, let anchorApp):
            Self.neighborMinimumText(
                appBound: appBound,
                app: Self.pillAppName(anchorApp)
            )
        case .ownMaximum(_, _, let atBoundary):
            atBoundary
                ? L("resize.boundary_reached", "No room left to grow")
                : L(
                    "resize.app_max_reached",
                    "This app won't go bigger"
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
        case .gridNoOtherTrack(_, let axis):
            axis == "y"
                ? L(
                    "resize.grid_no_other_row",
                    "No other row to take the height"
                )
                : L(
                    "resize.grid_no_other_column",
                    "No other column to take the width"
                )
        case .layoutHasNoResize:
            L(
                "resize.layout_has_none",
                "This layout has no resizing"
            )
        case .windowIsFullscreen:
            L(
                "resize.window_fullscreen",
                "Full-screen windows can't be resized"
            )
        case .fullscreenCannotMove:
            L(
                "resize.move_fullscreen",
                "Full-screen windows can't be moved"
            )
        case .moveNeedsFloat:
            L(
                "resize.move_needs_float",
                "Only a floating window can be moved"
            )
        case .moveAtBoundary:
            L("resize.move_boundary", "No room left to move")
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
        case .neighborMinimum(let anchor, _, let axis, let appBound, _):
            let mark = ResizeRefusal.ownMinimum(
                anchor,
                axis: axis,
                appBound: appBound
            )
            return (anchor, mark.pillText)
        default:
            return nil
        }
    }

    /// The trier's sentence for a neighbour floor; an empty name
    /// keeps the nameless one.
    @MainActor
    private static func neighborMinimumText(
        appBound: Bool,
        app: String
    ) -> String {
        switch (appBound, app.isEmpty) {
        case (true, true):
            L(
                "resize.neighbor_app_min",
                "Neighboring app won't go smaller"
            )
        case (false, true):
            L(
                "resize.neighbor_min_size",
                "Neighboring window at its minimum size"
            )
        case (true, false):
            L(
                "resize.neighbor_app_min_named",
                "Neighboring %1$@ window won't go smaller",
                app
            )
        case (false, false):
            L(
                "resize.neighbor_min_size_named",
                "Neighboring %1$@ window is at the minimum window size",
                app
            )
        }
    }

    /// The longest app name a pill spells out. A longer one is
    /// cut and ends in "…", so the sentence's verb survives the
    /// pill's own truncation.
    static let pillAppNameLimit = 20

    /// `name` trimmed, and cut to `pillAppNameLimit` characters.
    static func pillAppName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard trimmed.count > pillAppNameLimit else { return trimmed }
        let cut = trimmed.prefix(pillAppNameLimit - 1)
        return cut.trimmingCharacters(in: .whitespaces) + "…"
    }
}
