import KiwiDeskCore
import SwiftUI

/// Space removal and keyboard focus return target handling (#678 Phase 4).
extension SpacesSection {
    func removeSpace(_ space: SpaceID) {
        // From `displayedSpaces`, the rows the user sees mid-drag,
        // read before the mutation (`DeletionFocus`, #816).
        let neighbour = DeletionFocus.neighbour(
            after: space,
            in: displayedSpaces
        )
        model.removeSpace(space)
        returningRow = neighbour
    }
}
