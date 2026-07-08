import SwiftUI
import UniformTypeIdentifiers

/// In-app drag payload for the settings dashboard: a
/// same-process, model-level drag of a space chip onto a
/// monitor tile. (The Spaces-list reorder is a plain drag
/// *gesture*, not a drag session — no payload involved.)
///
/// It rides the system `.json` content type rather than a bespoke
/// `UTType(exportedAs:)`: KiwiDesk ships as a bare SwiftPM
/// executable with no bundle, so a custom exported type is never
/// registered with LaunchServices and its drops are silently
/// rejected (the chip snaps back). `.json` is always registered, so
/// the drop round-trips, while unrelated text drags still don't
/// match (`.json` ≠ `.plainText`).
struct DraggableSpace: Codable, Transferable {
    let raw: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
