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

    /// Live re-validation of the pending rejection (#34).
    var liveRejection: RecorderRejection? {
        guard let rejection, let preflight else { return nil }
        return preflight(rejection.combo)
    }
}
