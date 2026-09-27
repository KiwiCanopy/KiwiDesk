import CoreText
import KiwiDeskCore
import SwiftUI

extension HomeCardBarsTile.BarSpec {
    /// The bar text face at `size`: the shelf's own `textFont`,
    /// the accessor every live bar text site asks (#1681).
    @MainActor func textFont(size: CGFloat) -> Font {
        Font(shelf.textFont(ofSize: size) as CTFont)
    }
}
