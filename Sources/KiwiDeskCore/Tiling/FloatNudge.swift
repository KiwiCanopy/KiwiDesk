import CoreGraphics

/// Pure geometry calculations for nudging newly floating windows (#412).
public enum FloatNudge {
    /// Maximum nudge distance. The magnitude is FIXED, never
    /// proportional to window size: a size-scaled nudge teleports
    /// a maximized window and barely moves a tiny one; a window
    /// near the center tapers to ~0 on its own.
    public static let maxDistance: CGFloat = 24

    /// Calculates nudged target frame shifted toward visible center in AX
    /// coordinates.
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

    /// Confines window origin so frame stays entirely within visible bounds.
    static func confine(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let maxX = max(visible.minX, visible.maxX - frame.width)
        let maxY = max(visible.minY, visible.maxY - frame.height)
        let x = min(max(frame.minX, visible.minX), maxX)
        let y = min(max(frame.minY, visible.minY), maxY)
        return CGRect(x: x, y: y, width: frame.width, height: frame.height)
    }
}
