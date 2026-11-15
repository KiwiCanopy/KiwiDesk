import SwiftUI

/// The refused chord (#34): kept in the hosting `ShortcutKeyRow`,
/// which draws it as a line across the row (#3258), or in the field
/// where no row hosts it.
extension KeyRecorderField {
    var rejection: RecorderRejection? {
        get {
            if let conflictSlot { return conflictSlot.wrappedValue }
            return ownRejection
        }
        nonmutating set {
            if let conflictSlot {
                conflictSlot.wrappedValue = newValue
            } else {
                ownRejection = newValue
            }
        }
    }

    /// What an offer says, compared to tell a new holder apart.
    struct Offer: Equatable {
        let combo: String
        let holder: String
        let holderRowID: String
        let inStep: Bool

        init(_ rejection: RecorderRejection) {
            combo = rejection.combo
            holder = rejection.holder
            holderRowID = rejection.holderRowID
            inStep = rejection.inStep
        }
    }

    /// Live re-validation of the pending rejection (#34).
    var liveRejection: RecorderRejection? {
        guard let rejection, let preflight else { return nil }
        return preflight(rejection.combo)
    }
}
