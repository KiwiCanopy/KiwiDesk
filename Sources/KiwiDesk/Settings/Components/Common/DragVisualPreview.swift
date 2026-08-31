import KiwiDeskCore
import SwiftUI

/// Window tile mock preview for drag visual styling (`DragVisual`, #231).
struct DragVisualPreview: View {
    let visual: DragVisual
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
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

    /// Renders inside/outside border alignment preview
    /// (`DragOverlay.adjustedFrame`, #231).
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
                // Parallel offset corner radius R + width / 2.
                RoundedRectangle(cornerRadius: radius + width / 2)
                    .stroke(color, lineWidth: width)
                    .padding(-width / 2)
            }
        }
    }

    /// Linear interpolation of value across source/destination ranges
    /// (`GapPreviewScale`).
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
