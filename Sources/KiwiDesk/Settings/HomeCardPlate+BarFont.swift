import AppKit
import CoreText
import KiwiDeskCore
import SwiftUI

extension HomeCardBarsTile.BarSpec {
    /// The bar text face at `size`: the shelf's own `textFont`,
    /// the accessor every live bar text site asks (#1681).
    @MainActor func textFont(size: CGFloat) -> Font {
        Font(shelf.textFont(ofSize: size) as CTFont)
    }

    /// The slot an App Bar title draws in at the frame's font
    /// size, the live bar's one `BarTitleSlot` (#2545); nil where
    /// the bar has no title cap.
    @MainActor var titleSlot: CGFloat? {
        titleCap.map {
            BarTitleSlot.length(
                cap: $0,
                font: shelf.textFont(ofSize: fontSize)
            )
        }
    }

    /// The along-axis length of the glyph `BarStripView.iconAndTitle`
    /// draws for an icon item, padding excluded.
    @MainActor func glyphLength(
        _ item: HomeCardBarsTile.BarItem,
        vertical: Bool
    ) -> CGFloat {
        guard let glyph = item.glyph else { return item.length }
        let size = Self.glyphSize(glyph, size: fontSize * item.glyphRatio)
        return vertical ? size.height : size.width
    }

    /// The along-axis length of a labelled item's glyph or text as
    /// `BarStripView.iconAndTitle` draws it, padding excluded; a
    /// text label in the bar's own face (#2890).
    @MainActor func labelledLength(
        _ item: HomeCardBarsTile.BarItem,
        vertical: Bool
    ) -> CGFloat {
        guard let text = item.label else {
            return glyphLength(item, vertical: vertical)
        }
        let size = NSAttributedString(
            string: text,
            attributes: [.font: shelf.textFont(ofSize: fontSize)]
        ).size()
        return ceil(vertical ? size.height : size.width)
    }

    /// A symbol's size as SwiftUI draws it at `size`, measured
    /// once per pair: AppKit's own symbol size differs by a point.
    @MainActor private static func glyphSize(
        _ name: String,
        size: CGFloat
    ) -> CGSize {
        let key = "\(name)@\(size)"
        if let measured = glyphSizes[key] { return measured }
        let measured =
            ImageRenderer(
                content: Image(systemName: name).font(.system(size: size))
            ).nsImage?.size ?? .zero
        glyphSizes[key] = measured
        return measured
    }

    @MainActor private static var glyphSizes: [String: CGSize] = [:]
}
