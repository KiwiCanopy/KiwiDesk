import Foundation

/// Whether a bar's shelf stays on screen (#761): `always`, or
/// `auto`, which hides it to an indicator the pointer reveals.
/// Read through `TilingSettings.visibility(of:)`, which makes two
/// bars sharing an edge on any screen one answer, and written
/// through `setVisibility(_:of:)`; a hiding edge reserves only its
/// constant sliver (`KiwiShelf.hiddenReservation`), so a reveal
/// draws over the windows.
public enum ShelfVisibility: String, Sendable, Codable, CaseIterable {
    case always
    case auto
}

/// Which bar a shelf question names (#761).
public enum ShelfBar: Sendable, Hashable {
    case space
    case app
}
