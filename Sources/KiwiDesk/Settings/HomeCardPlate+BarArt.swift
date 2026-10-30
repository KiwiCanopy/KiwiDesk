import CoreText
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
                    .offset(x: Self.inkShift(ligature, font))
                    .frame(width: side, height: side)
            }
        }
    }

    /// How far to move a ligature so its INK centres on its frame,
    /// as the live bar's `BarTextGlyph` places it: an App Font
    /// glyph's slack sits on its trailing side (#1529).
    static func inkShift(_ ligature: String, _ font: NSFont) -> CGFloat {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: ligature, attributes: [.font: font])
        )
        let advance = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        return advance / 2 - ink.midX
    }
}

extension HomeCardBarsTile.BarSpec {
    /// An art item's side: the App Bar glyph's slot at the bar's
    /// font size, so an icon sits at the digits' height.
    var artSide: CGFloat {
        fontSize * AppBarStyle.glyphSlotRatio * 1.2
    }
}
