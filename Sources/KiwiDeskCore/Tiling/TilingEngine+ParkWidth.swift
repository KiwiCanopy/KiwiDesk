import CoreGraphics

/// A bottom-left park at the width the window draws (#2759). The
/// corner anchors the right edge, so a park laid at a layout's ask
/// narrower than the app draws sticks out until the learner knows
/// the app's minimum. The drawn width is already at least that
/// minimum, so the issued park leaves the peek from the first one.
/// Layouts never see current frames, so the issued set lays it.
extension TilingEngine {
    /// `frames` with every bottom-left park on `bounds` laid at its
    /// window's state width where that is wider. Part of the issued
    /// set (`placedFrames`), so every reader of where a window is
    /// agrees with what the retile sends.
    func parkingAtDrawnWidth(
        _ frames: [WindowID: CGRect],
        state: StateCoordinator,
        in bounds: CGRect
    ) -> [WindowID: CGRect] {
        frames.reduce(into: frames) { out, entry in
            guard let drawn = state.windows[entry.key]?.frame
            else { return }
            out[entry.key] = Self.parkAtDrawnWidth(
                entry.value,
                drawn: drawn,
                in: bounds
            )
        }
    }

    /// One frame: a bottom-left park on `bounds` re-laid at the
    /// drawn width where that is wider than its own. Any other
    /// frame, the right corner's park among them (its x is
    /// width-free), passes unchanged.
    static func parkAtDrawnWidth(
        _ target: CGRect,
        drawn: CGRect,
        in bounds: CGRect
    ) -> CGRect {
        guard drawn.width > target.width,
            parked(
                target,
                at: stashFrame(target, in: bounds, corner: .bottomLeft)
            )
        else { return target }
        let wide = CGRect(
            origin: target.origin,
            size: CGSize(width: drawn.width, height: target.height)
        )
        return stashFrame(wide, in: bounds, corner: .bottomLeft)
    }
}
