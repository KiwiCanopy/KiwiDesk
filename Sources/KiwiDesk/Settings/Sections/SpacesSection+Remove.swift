import KiwiDeskCore
import SwiftUI

/// Removing a space, and where the keyboard lands afterwards.
/// Split from `SpacesSection` at the §2.1 ceiling — the focus
/// destination is what made this more than a one-line mutation
/// (#678 Phase 4 pass 10).
extension SpacesSection {
    func removeSpace(_ space: SpaceID) {
        // Where focus goes AFTER the row it was on stops existing
        // (#678 Phase 4 pass 10, turn 20a rule 4: deleting moves
        // focus to the next row, never to the top). Read BEFORE
        // the mutation — the neighbour is defined by the list the
        // deletion is about to change, and reading it afterwards
        // names whichever row slid into the gap only by accident.
        //
        // Falls BACKWARD when the deleted row was last, which is
        // the only direction left, and to nil on the last row of
        // all, where there is genuinely nowhere to be.
        let neighbour = neighbourAfterDeleting(space)
        model.config.removeSpace(space)
        if model.nav.spaceOverridesFocus == space {
            model.nav.spaceOverridesFocus = nil
        }
        returningRow = neighbour
    }

    /// The row a deletion should leave focus on: the next one
    /// down, else the previous, else nothing.
    private func neighbourAfterDeleting(
        _ space: SpaceID
    ) -> SpaceID? {
        // `displayedSpaces`, not `model.config.spaces`: while a
        // drag is in flight the rows render from the local
        // `dragOrder`, and the neighbour has to be the one the
        // user can SEE below the row they deleted. Practically
        // unreachable today (the delete goes through a
        // confirmation dialog, which no drag survives) — read
        // this way so the claim in the comment above is true
        // rather than nearly true (code review, 2026-08-11).
        let spaces = displayedSpaces
        guard let index = spaces.firstIndex(of: space) else {
            return nil
        }
        if index + 1 < spaces.count { return spaces[index + 1] }
        return index > 0 ? spaces[index - 1] : nil
    }
}
