import CoreGraphics

/// Pure geometry for the float nudge (#412 sibling polish).
///
/// Toggling a window tiled→floating keeps its exact frame, so the
/// toggle looks inert — nothing moved. A small fixed shove toward
/// the current screen's visible-frame center acknowledges the
/// state change.
///
/// The magnitude is FIXED (`min(maxDistance, distanceToCenter)`),
/// never proportional to the window size: a size-scaled nudge
/// teleports a maximized window and barely moves a tiny one. A
/// window already near the center tapers to ~0 on its own (the
/// distance term shrinks), so no edge special-casing is needed.
///
/// All math is a pure function over the window frame and the
/// screen's AX visible frame — no AX, no AppKit — so it is
/// unit-testable and safe to call off the layout hot path.
public enum FloatNudge {
    /// Cap on the shove, in points. Small enough to read as a
    /// nudge (an acknowledgement), not a real move.
    public static let maxDistance: CGFloat = 24

    /// The nudged target frame for a floating window, shoved
    /// toward `visible`'s center and confined fully inside
    /// `visible` so it can never slip under the menu bar / a
    /// reserved strip or partly off-screen.
    ///
    /// AX coordinates (origin top-left, y grows downward), so the
    /// visible frame's bottom edge is `visible.maxY`.
    public static func target(
        frame: CGRect,
        visible: CGRect,
        maxDistance: CGFloat = FloatNudge.maxDistance
    ) -> CGRect {
        let dx = visible.midX - frame.midX
        let dy = visible.midY - frame.midY
        let distance = (dx * dx + dy * dy).squareRoot()

        let offset: CGVector
        if distance < 1 {
            // Direction undefined at dead center: shove straight
            // down toward the visible frame's bottom edge.
            let room = max(0, visible.maxY - frame.midY)
            offset = CGVector(dx: 0, dy: min(maxDistance, room))
        } else {
            let magnitude = min(maxDistance, distance)
            offset = CGVector(
                dx: dx / distance * magnitude,
                dy: dy / distance * magnitude
            )
        }

        let moved = frame.offsetBy(dx: offset.dx, dy: offset.dy)
        return confine(moved, to: visible)
    }

    /// Clamps `frame`'s origin so the frame sits fully inside
    /// `visible` (position only, size untouched) — the same "keep
    /// it on screen" intent tiled placement gets for free from
    /// its pure layout functions. A frame larger than `visible`
    /// on an axis pins to that axis's min edge.
    static func confine(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let maxX = max(visible.minX, visible.maxX - frame.width)
        let maxY = max(visible.minY, visible.maxY - frame.height)
        let x = min(max(frame.minX, visible.minX), maxX)
        let y = min(max(frame.minY, visible.minY), maxY)
        return CGRect(x: x, y: y, width: frame.width, height: frame.height)
    }
}
