import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// The edge of a plate or box in the Bars preview: the shelf's
/// border where the draft draws one (#1679), else the schematic's
/// own hairline, so a plate still reads against the well.
struct PreviewPlateEdge: View {
    let spec: HomeCardBarsTile.BarSpec
    let corner: CGFloat
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        if spec.borderWidth > 0 {
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(
                    Color(kiwiHex: spec.borderColor),
                    lineWidth: spec.borderWidth
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
