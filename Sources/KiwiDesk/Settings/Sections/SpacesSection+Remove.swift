import KiwiDeskCore
import SwiftUI

/// Space removal and keyboard focus return target handling (#678 Phase 4).
extension SpacesSection {
    func removeSpace(_ space: SpaceID) {
        // Read the neighbour BEFORE the mutation (`DeletionFocus`,
        // #816). `displayedSpaces`, not `model.config.spaces`:
        // mid-drag the rows render from `dragOrder`, and the
        // neighbour must be the one the user can SEE (review
        // 2026-08-11).
        let neighbour = DeletionFocus.neighbour(
            after: space,
            in: displayedSpaces
        )
        model.removeSpace(space)
        returningRow = neighbour
    }
}
