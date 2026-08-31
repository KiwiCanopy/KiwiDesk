import KiwiDeskCore
import SwiftUI

/// Space removal and keyboard focus return target handling (#678 Phase 4).
extension SpacesSection {
    func removeSpace(_ space: SpaceID) {
        // Compute focus neighbor before mutation (#678 Phase 4 pass 10).
        let neighbour = neighbourAfterDeleting(space)
        model.config.removeSpace(space)
        if model.nav.spaceOverridesFocus == space {
            model.nav.spaceOverridesFocus = nil
        }
        returningRow = neighbour
    }

    /// Focus target following space deletion: next row, else previous.
    private func neighbourAfterDeleting(
        _ space: SpaceID
    ) -> SpaceID? {
        let spaces = displayedSpaces
        guard let index = spaces.firstIndex(of: space) else {
            return nil
        }
        if index + 1 < spaces.count { return spaces[index + 1] }
        return index > 0 ? spaces[index - 1] : nil
    }
}
