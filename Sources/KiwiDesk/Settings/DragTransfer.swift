import SwiftUI
import UniformTypeIdentifiers

/// In-app drag payload transferring a space chip onto a monitor tile.
struct DraggableSpace: Codable, Transferable {
    let raw: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
