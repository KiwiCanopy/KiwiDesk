import SwiftUI
import UniformTypeIdentifiers

/// In-app drag payload transferring a space chip onto a monitor
/// tile. Rides the system `.json` type, never a bespoke
/// `UTType(exportedAs:)`: a bare SwiftPM executable has no
/// bundle, so a custom exported type is never registered with
/// LaunchServices and its drops are silently rejected.
struct DraggableSpace: Codable, Transferable {
    let raw: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
