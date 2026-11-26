import CoreGraphics

/// The `refuse*` builders (#1258): each builds one `ResizeRefusal`
/// and hands it to `cueResizeRefusal`, which draws, bumps and sounds.
extension KiwiCore {
    /// The zone has no parameter on the asked axis (#1255).
    func refuseAxisAbsent(_ window: WindowID, axis: String) {
        cueResizeRefusal(.noAxisHere(window, axis: axis))
    }

    /// The group this axis divides has one member (#1258);
    /// `otherAxisDivides` is the caller's reading of its own
    /// partition, and rides the case so a test can see it.
    func refuseNothingToDivide(
        _ window: WindowID,
        otherAxisDivides: Bool
    ) {
        cueResizeRefusal(
            .nothingToDivide(
                window,
                otherAxisDivides: otherAxisDivides
            )
        )
    }

    /// A Grid cell already fills `axis` (#2707): a grow meets
    /// the tiling area's edge, a shrink finds no other row or
    /// column to hand the space to.
    func refuseGridSpansAxis(
        _ window: WindowID,
        axis: String,
        delta: Double
    ) {
        if delta > 0 {
            refuseGrowAtBoundary(window, axis: axis)
        } else {
            cueResizeRefusal(.gridNoOtherTrack(window, axis: axis))
        }
    }

    /// The layout has no resizing at all (#1255): monocle and
    /// grid. A correct no-op — macOS's own full-screen exposes
    /// no resize either — but a perceivable one, and it is the
    /// MOST reachable refusal in the feature, not the least: any
    /// resize press in either arrives here. It cued by sound
    /// alone until #1255.
    ///
    /// An empty space cues nothing: every refusal is drawn ON a
    /// window, so with no focus there is nothing to draw and
    /// nothing to sound beside it.
    func refuseResizeUnsupported(in space: Space) {
        guard let window = space.focused else { return }
        cueResizeRefusal(.layoutHasNoResize(window))
    }

    /// The focused window is in native full screen (#1298).
    func refuseWindowIsFullscreen(_ window: WindowID) {
        cueResizeRefusal(.windowIsFullscreen(window))
    }

    /// A float-move verb on a full-screen focus (#3007).
    func refuseMoveWhileFullscreen(_ window: WindowID) {
        cueResizeRefusal(.fullscreenCannotMove(window))
    }

    /// A float-move verb on a tiled focus (#3007).
    func refuseMoveNotFloating(_ window: WindowID) {
        cueResizeRefusal(.moveNeedsFloat(window))
    }

    /// `move_floating` stopped at its reach (#2972, #3163).
    func refuseMoveAtBoundary(_ window: WindowID, _ to: Direction) {
        cueResizeRefusal(.moveAtBoundary(window, direction: to))
    }

    /// A shrink hit the window's effective minimum (#933) — on
    /// the FIRST attempt the clamp truncates, landing ON the
    /// minimum included, not only once already there. Whose
    /// floor bound is derived here (#1261); `raisedBy` is the
    /// floor a clamp adds beside `min_window_size`, if any.
    func refuseShrinkAtMinimum(
        _ window: WindowID,
        axis: String,
        raisedBy floor: Double = 0
    ) {
        cueResizeRefusal(
            .ownMinimum(
                window,
                axis: axis,
                appBound: minimumIsAppBound(
                    of: window,
                    axis: axis,
                    raisedBy: floor
                )
            )
        )
    }

    /// A grow refused at the window's own learned app-enforced
    /// maximum (#1055) — `refuseShrinkAtMinimum`'s mirror at the
    /// other end. One pill only: the limit is the resized
    /// window's own app, so there is no second window to mark —
    /// and the sentence says so (#1261), needing no
    /// discriminator since no configured maximum exists.
    func refuseGrowAtMaximum(_ window: WindowID, axis: String) {
        cueResizeRefusal(
            .ownMaximum(window, axis: axis, atBoundary: false)
        )
    }

    /// A press stopped at the stored limit of the ratio or weight it
    /// moves (#3643), named by the press's sign.
    func refuseRatioLimit(
        _ window: WindowID,
        axis: String,
        grows: Bool
    ) {
        cueResizeRefusal(.ratioLimit(window, axis: axis, grows: grows))
    }

    /// A press on a float whose size macOS says cannot be set (#2994):
    /// the app's own limit either way, on macOS's statement rather
    /// than a learned floor or ceiling. The one verdict no derivation
    /// answers (`RefusalCueSeamTests`).
    func refuseFixedSize(
        _ window: WindowID,
        axis: String,
        shrinks: Bool
    ) {
        cueResizeRefusal(
            shrinks
                ? .ownMinimum(
                    window,
                    axis: axis,
                    appBound: true
                )
                : .ownMaximum(window, axis: axis, atBoundary: false)
        )
    }

    /// A float grow refused because BOTH edges are against the
    /// region it may occupy — the screen less its bars (#1091) —
    /// or a Grid cell grow where the cell already fills the axis
    /// (#2707).
    ///
    /// Shares `.ownMaximum` rather than taking a case of its
    /// own, and that is a RULING: every consumer of the reason
    /// acts on "the resized window hit its own ceiling" and
    /// would do the same for either wall. Only the WORDS tell a
    /// learned app maximum from a screen edge apart, which is
    /// why the distinction rides the case as a flag the renderer
    /// reads rather than as a second case — observable at the
    /// seam either way (#1258), where before #1258 it was
    /// observable at neither.
    func refuseGrowAtBoundary(_ window: WindowID, axis: String) {
        cueResizeRefusal(
            .ownMaximum(window, axis: axis, atBoundary: true)
        )
    }

    /// A resize refused because a NEIGHBOR sits at its own
    /// effective minimum (#933). The pairing — which window
    /// wears the second pill, and what it says — is the
    /// renderer's (`ResizeRefusal.secondPill`); whose floor the
    /// anchor sits at is derived from the anchor (#1261).
    func refuseGrowAtNeighborMinimum(
        _ focused: WindowID,
        anchor: WindowID,
        axis: String
    ) {
        cueResizeRefusal(
            .neighborMinimum(
                anchor: anchor,
                focused: focused,
                axis: axis,
                appBound: minimumIsAppBound(of: anchor, axis: axis),
                anchorApp: anchorAppName(of: anchor)
            )
        )
    }

    /// The split heal's unfit floor (#934): `overhanging` cannot
    /// be made room for because `anchor` already sits at its own
    /// floor — the neighbour-minimum pair, drawn by a retile
    /// rather than a press.
    func refuseFloorUnfitAtRetile(
        _ overhanging: WindowID,
        anchor: WindowID,
        axis: String
    ) {
        cueResizeRefusal(
            .neighborMinimum(
                anchor: anchor,
                focused: overhanging,
                axis: axis,
                appBound: minimumIsAppBound(of: anchor, axis: axis),
                anchorApp: anchorAppName(of: anchor)
            ),
            fromPress: false
        )
    }
}
