import Foundation
import KiwiDeskCore

/// A pick that created nothing, and where it was made (#1235).
///
/// The app rather than a message: the sentence is derived from
/// the live question each render, so freeing a behavior clears
/// it with nothing having to notice. The row is what lets the
/// caption appear at the picker that refused.
struct AppPickRefusal: Equatable {
    let app: KeybindingCatalog.InstalledApp
    /// The binding whose picker refused, or nil for the add row.
    let row: UUID?
}
