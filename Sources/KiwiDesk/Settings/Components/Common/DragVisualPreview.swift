import KiwiDeskCore
import SwiftUI

/// Window tile mock preview for drag visual styling (`DragVisual`, #231).
struct DragVisualPreview: View {
    let visual: DragVisual
    /// Every window outline's width and corners (#1742).
    let stroke: WindowStroke
    /// The stored `dragLiquidGlass` leaf; Core gates it.
    let glass: Bool
    /// `border.sheen` (#1644).
    let sheen: CGFloat

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

    /// The marker as Core draws it, at the preview's scale: the
    /// engine's own view, so glass, tint and fade are the drag's
    /// (#702, #1645).
    private var mock: some View {
        let scaled = WindowStroke(
            width: scale(stroke.width, from: 0...20, to: 0...10),
            cornerRadius: stroke.cornerRadius > 0
                ? FocusBorderPreview.roundedRadius : 0
        )
        // `DragOverlay.adjustedFrame`: the border straddles the
        // slot edge by half its width, inward or outward (#231).
        let half = visual.border ? scaled.width / 2 : 0
        return DragMarkerHost(
            style: visual,
            stroke: scaled,
            glass: glass,
            sheen: sheen
        )
        .padding(visual.borderAlignment == .inside ? half : -half)
        .opacity(visual.enabled ? 1 : 0.25)
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

/// Hosts Core's `DragMarkerView`, which resolves the glass leaf
/// through its own gate.
private struct DragMarkerHost: NSViewRepresentable {
    let style: DragVisual
    let stroke: WindowStroke
    let glass: Bool
    let sheen: CGFloat

    func makeNSView(context: Context) -> DragMarkerView {
        DragMarkerView()
    }

    func updateNSView(_ view: DragMarkerView, context: Context) {
        view.showPreview(
            style,
            stroke: stroke,
            storedGlass: glass,
            sheen: sheen
        )
    }
}
