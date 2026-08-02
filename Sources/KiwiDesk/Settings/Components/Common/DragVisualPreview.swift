import KiwiDeskCore
import SwiftUI

/// Shared by the Gaps & Borders drag editor (structure) and the
/// Advanced Colours Drag group (tints) — the same recycled-preview
/// rule as `FocusBorderPreview`, and the #231 twin columns are
/// reproduced on the colour page for the same reason they exist
/// here: tuning one column must never scroll its preview away.
///
/// One mock window rect rendered with the current visual's
/// fill, border, and the shared corner radius.
struct DragVisualPreview: View {
    let visual: DragVisual
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            // A neutral desktop backdrop so translucent
            // fills read realistically.
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            mock
                .padding(10)
            if !visual.enabled {
                Text(L("drag.disabled", "disabled"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 84)
        .frame(maxWidth: .infinity)
    }

    private var mock: some View {
        // Remap the full slider ranges onto the preview's
        // smaller span (the AppBarPreviewStrip / GapPreviewScale
        // fix, #231): a hard cap made both sliders visibly stop
        // responding halfway up, reading as "the setting broke."
        let radius = scale(cornerRadius, from: 0...40, to: 0...20)
        let width = scale(
            visual.borderWidth,
            from: 0...20,
            to: 0...10
        )
        return RoundedRectangle(cornerRadius: radius)
            .fill(
                visual.fill
                    ? Color(kiwiHex: visual.fillColor) : .clear
            )
            .overlay { border(radius: radius, width: width) }
            .opacity(visual.enabled ? 1 : 0.25)
    }

    /// Illustrate the footprint each alignment gives at runtime
    /// (`DragOverlay.adjustedFrame`, #231): inset within the
    /// tile for `.inside`, sitting outside the tile edge for
    /// `.outside`. Schematic, not pixel-exact — the point is the
    /// larger outward footprint, sized to half the (scaled)
    /// width the slider drives so the difference grows with the
    /// same number the user is dragging.
    @ViewBuilder private func border(
        radius: CGFloat,
        width: CGFloat
    ) -> some View {
        if visual.border {
            let color = Color(kiwiHex: visual.borderColor)
            switch visual.borderAlignment {
            case .inside:
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(color, lineWidth: width)
            case .outside:
                // Grow the corner radius with the outward offset
                // (a parallel offset of a rounded rect by d has
                // radius R + d) so the border's inner corner
                // stays flush with the tile's rounded corner —
                // keeping `radius` here left a backdrop sliver in
                // each corner.
                RoundedRectangle(cornerRadius: radius + width / 2)
                    .stroke(color, lineWidth: width)
                    .padding(-width / 2)
            }
        }
    }

    /// Linear map of `value` from one closed range onto another,
    /// clamped to the target range at the ends (mirrors
    /// `AppBarPreviewStrip.scale`).
    private func scale(
        _ value: CGFloat,
        from src: ClosedRange<CGFloat>,
        to dst: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = src.upperBound - src.lowerBound
        guard span > 0 else { return dst.lowerBound }
        let t = min(max((value - src.lowerBound) / span, 0), 1)
        return dst.lowerBound
            + t * (dst.upperBound - dst.lowerBound)
    }
}
