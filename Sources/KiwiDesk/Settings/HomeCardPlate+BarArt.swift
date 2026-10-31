import KiwiDeskCore
import SwiftUI

/// An App Bar item's real art in the bars preview (#1740): the
/// app's own icon, or its App Font ligature in the item's ink, at
/// the bar's own font size as the live bar's glyph.
extension BarStripView {
    @ViewBuilder
    func artView(_ art: HomeCardBarsTile.BarArt) -> some View {
        let side = spec.artSide
        switch art {
        case .icon(let image):
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: side, height: side)
        case .appFont(let ligature):
            if let font = AppFont.font(size: side * 0.85) {
                Text(ligature).font(Font(font))
                    .fixedSize()
                    .offset(
                        x: BarTextGlyph.inkCentringShift(ligature, font: font)
                    )
                    .frame(width: side, height: side)
            }
        }
    }
}

extension HomeCardBarsTile.BarSpec {
    /// An art item's side: the App Bar glyph's slot at the bar's
    /// font size, so an icon sits at the digits' height.
    var artSide: CGFloat {
        fontSize * AppBarStyle.glyphSlotRatio
    }
}
