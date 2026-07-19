import KiwiDeskCore
import SwiftUI

// The mock can't be to-scale (a 200 pt tab won't fit an 84 pt
// canvas), so each dimension maps its full real range onto a
// legible preview range *proportionally* — dragging any
// slider always keeps moving the mock, rather than hitting a
// hard cap partway (which read as "the setting stopped
// working"). Relative, not absolute; the slider readouts show
// the true pt values.
//
// Split from AppBarPreviewStrip.swift (file-size ceiling); the
// SpaceBar twin keeps its metrics inline — its budget block is
// smaller.
extension AppBarPreviewStrip {
    /// Real thickness 20–80 pt → 14–44 pt of canvas depth.
    var thickness: CGFloat {
        scale(style.thickness, from: 20...80, to: 14...44)
    }

    /// Real gap 0–40 pt → 0–16 pt (0–5 pt on a vertical bar,
    /// where the inner-box height budgets the axis).
    var gap: CGFloat {
        style.edge.isHorizontal
            ? scale(style.boxGap, from: 0...40, to: 0...16)
            : scale(style.boxGap, from: 0...40, to: 0...5)
    }

    /// The shared %-resolve against the preview's own (scaled)
    /// thickness, so the mock rounds like the runtime bar;
    /// clamped to the slot's smaller dimension so a vertical
    /// bar's short slots keep sane corners.
    var corner: CGFloat {
        min(
            style.resolvedCornerRadius(forThickness: thickness),
            min(slotWidth, slotHeight) / 2
        )
    }

    /// Box length along the bar axis: honor an explicit
    /// `boxSize` (mapped 1–200 pt → 20–72 pt), else size to the
    /// content kind.
    var slotLength: CGFloat {
        if style.boxSize > 0 {
            return scale(style.boxSize, from: 1...200, to: 20...72)
        }
        switch style.content {
        case .icon: return max(thickness, 22)
        case .name: return 44
        case .iconAndName: return 56
        }
    }

    /// Length along a **vertical** bar's axis, compressed so
    /// three slots plus gaps stay inside the 72 pt inner box
    /// (the 84 pt canvas minus the 12 pt edge-hug inset):
    /// 3 × 18 + 2 × 5 + 8 strip padding = 72 at the maxima.
    /// The box-size slider still visibly moves the mock.
    var verticalSlotLength: CGFloat {
        if style.boxSize > 0 {
            return scale(style.boxSize, from: 1...200, to: 14...18)
        }
        return 16
    }

    /// Concrete slot frame for the current orientation: along a
    /// horizontal bar the length runs in x and the thickness in
    /// y; a vertical bar swaps them.
    var slotWidth: CGFloat {
        style.edge.isHorizontal ? slotLength : thickness
    }
    var slotHeight: CGFloat {
        style.edge.isHorizontal ? thickness : verticalSlotLength
    }

    /// Linear map of `value` from one closed range onto another,
    /// clamped to the target range at the ends.
    func scale(
        _ value: CGFloat,
        from src: ClosedRange<CGFloat>,
        to dst: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = src.upperBound - src.lowerBound
        guard span > 0 else { return dst.lowerBound }
        let t = (value - src.lowerBound) / span
        let mapped =
            dst.lowerBound
            + min(max(t, 0), 1) * (dst.upperBound - dst.lowerBound)
        return mapped
    }

    var font: CGFloat {
        let base =
            style.fontSize > 0
            ? style.fontSize : thickness * 0.42
        return min(base, thickness * 0.55, slotHeight * 0.55)
    }
}
