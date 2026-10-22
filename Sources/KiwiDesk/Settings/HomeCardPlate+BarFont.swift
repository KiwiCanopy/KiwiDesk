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
}
