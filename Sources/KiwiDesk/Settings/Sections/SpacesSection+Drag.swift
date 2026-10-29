import KiwiDeskCore
import SwiftUI

/// The Spaces list's reorder (`SpaceReorder`, #68).
extension SpacesSection {
    /// Ordered space list for rendering during drag (#299).
    var displayedSpaces: [SpaceID] {
        reorder.displayed(model.config.spaces)
    }

    func dragHandle(_ space: SpaceID) -> some View {
        SpaceDragHandle(model: model, reorder: reorder, space: space)
    }
}
