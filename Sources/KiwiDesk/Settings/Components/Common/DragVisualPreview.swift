import KiwiDeskCore
import SwiftUI

/// Window tile mock preview for one drag marker (#231, #2797).
struct DragVisualPreview: View {
    let kind: DragMarkerView.Kind
    let visual: DragVisual
    /// Every window outline's corners (#1742).
    let stroke: WindowStroke
    /// The stored `dragLiquidGlass` leaf; Core gates it.
    let glass: Bool

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
    /// engine's own view (#702, #1645).
    private var mock: some View {
        DragMarkerHost(
            kind: kind,
            cornerRadius: stroke.cornerRadius > 0
                ? FocusBorderPreview.roundedRadius : 0,
            glass: glass
        )
        .opacity(visual.enabled ? 1 : 0.25)
    }
}

/// Hosts Core's `DragMarkerView`, so the picture is the drag's own
/// drawing (#702, #1645); the view resolves the glass leaf through
/// its own gate.
private struct DragMarkerHost: NSViewRepresentable {
    let kind: DragMarkerView.Kind
    let cornerRadius: CGFloat
    let glass: Bool

    func makeNSView(context: Context) -> DragMarkerView {
        DragMarkerView()
    }

    func updateNSView(_ view: DragMarkerView, context: Context) {
        view.showPreview(
            kind,
            cornerRadius: cornerRadius,
            storedGlass: glass
        )
    }
}
