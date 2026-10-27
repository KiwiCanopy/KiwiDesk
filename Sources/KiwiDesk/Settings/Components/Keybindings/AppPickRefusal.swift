import Foundation
import KiwiDeskCore

/// An add-row pick that created nothing (#1235).
///
/// The app rather than a message: the sentence is derived from
/// the live question each render, so freeing an action clears
/// it with nothing having to notice.
struct AppPickRefusal: Equatable {
    let app: KeybindingCatalog.InstalledApp
}
