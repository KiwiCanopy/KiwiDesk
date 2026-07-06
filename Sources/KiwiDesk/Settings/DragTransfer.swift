import SwiftUI
import UniformTypeIdentifiers

/// In-app drag payloads for the settings dashboard. These are
/// same-process, model-level drags (a space chip onto a monitor
/// tile, a profile chip onto a native Space), so each carries a
/// bare identifier under a dedicated content type rather than a
/// generic string — keeping unrelated text drags out.
extension UTType {
    /// A `SpaceID.raw` dragged from the space palette (#6).
    static let kiwiSpaceID = UTType(
        exportedAs: "com.kiwidesk.space-id"
    )
    /// A profile name dragged onto a native Space (#7).
    static let kiwiProfileName = UTType(
        exportedAs: "com.kiwidesk.profile-name"
    )
}

/// A virtual space being dragged onto a monitor (#6).
struct DraggableSpace: Codable, Transferable {
    let raw: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .kiwiSpaceID)
    }
}

/// A saved profile being dragged onto a native macOS Space (#7).
struct DraggableProfile: Codable, Transferable {
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .kiwiProfileName)
    }
}
