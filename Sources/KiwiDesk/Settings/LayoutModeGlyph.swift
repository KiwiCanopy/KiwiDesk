import KiwiDeskCore
import SwiftUI

/// One glyph per layout mode (#68 §6.3), used wherever a mode
/// is named — the space rows' mode picker, the Layout Defaults
/// section headers, the App Bar override headers, the preset
/// thumbnails — so the association gets learned. The glyph is
/// never the only signifier; it always accompanies the label.
extension LayoutMode {
    var glyph: String {
        switch self {
        case .bsp:
            return "square.split.bottomrightquarter"
        case .stack:
            return "rectangle.leadinghalf.inset.filled"
        case .scrolling:
            return "arrow.left.and.right.square"
        case .grid:
            return "square.grid.3x3"
        case .monocle:
            return "rectangle.inset.filled"
        case .floating:
            return "rectangle.on.rectangle"
        }
    }

    var displayName: String { rawValue.capitalized }
}
