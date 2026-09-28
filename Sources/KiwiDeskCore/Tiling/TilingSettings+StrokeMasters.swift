import CoreGraphics
import Foundation

/// The Borders card's two masters (#754): one width and one
/// corner decision over the focus ring and both drag strokes —
/// the one copy the card and a look (#1739) write through, so
/// neither leaves the strokes disagreeing.
extension TilingSettings {
    /// Writes `width` to all three strokes.
    public mutating func setStrokeWidth(_ width: CGFloat) {
        borderStyle.width = width
        dragGhost.borderWidth = width
        dragDropZone.borderWidth = width
    }

    /// Square is the ring's square style AND a zero drag radius;
    /// Rounded is the rounded style AND, only where there is no
    /// rounding to keep, the system window radius — so a repeat
    /// pick changes nothing.
    public mutating func setStrokeCorners(
        _ style: BorderStyle.CornerStyle
    ) {
        borderStyle.cornerStyle = style
        if style == .square {
            dragCornerRadius = 0
        } else if dragCornerRadius <= 0 {
            dragCornerRadius = GeometryUtils.systemWindowCornerRadius
        }
    }
}
