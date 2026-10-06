import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// The edge of a plate or box in the Bars preview: the shelf's
/// border where the draft draws one (#1679), else the schematic's
/// own hairline, so a plate still reads against the well.
struct PreviewPlateEdge: View {
    let spec: HomeCardBarsTile.BarSpec
    let corner: CGFloat
    /// The active indicator drawn over this edge, nil where none
    /// is; the border stands down under one that strokes the
    /// box's edge, as on the bar (#1924).
    var under: AppBarStyle.ActiveIndicator? = nil
    @Environment(\.schematicPalette) private var palette

    /// The border this edge strokes — its hex and width — or nil
    /// where the draft draws none and the hairline stands in.
    var border: (hex: String, width: CGFloat)? {
        spec.borderWidth > 0 ? (spec.borderColor, spec.borderWidth) : nil
    }

    /// Whether the border stands down under the indicator. The
    /// hairline is the schematic's own edge, not the shelf's
    /// border, so it stays (#1924).
    var standsDown: Bool {
        border != nil && under?.strokesBoxEdge == true
    }

    var body: some View {
        if standsDown {
            EmptyView()
        } else if let border {
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(
                    SheenPaint.style(border.hex, sheen: spec.sheen),
                    lineWidth: border.width
                )
        } else {
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(
                    palette?.frame
                        ?? SettingsTheme.plateInk.opacity(0.3)
                )
        }
    }
}
