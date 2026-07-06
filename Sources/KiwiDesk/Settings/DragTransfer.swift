import SwiftUI
import UniformTypeIdentifiers

/// In-app drag payloads for the settings dashboard. These are
/// same-process, model-level drags (a space chip onto a monitor
/// tile, a profile chip onto a native Space).
///
/// They ride the system `.json` content type rather than a bespoke
/// `UTType(exportedAs:)`: KiwiDesk ships as a bare SwiftPM
/// executable with no bundle, so a custom exported type is never
/// registered with LaunchServices and its drops are silently
/// rejected (the chip snaps back). `.json` is always registered, so
/// the drop round-trips. Unrelated text drags still don't match
/// (`.json` ≠ `.plainText`), and a space dropped where a profile is
/// expected (or vice versa) fails the `Codable` shape check — the
/// two structs have disjoint keys — so the drop is rejected.
struct DraggableSpace: Codable, Transferable {
    let raw: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// A saved profile being dragged onto a native macOS Space (#7).
struct DraggableProfile: Codable, Transferable {
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
