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

    /// Provider for the `DropDelegate`-based live reorder in
    /// the Spaces list, which needs `.onDrag`'s drag-start
    /// hook (`.draggable` has none). Same `.json` payload as
    /// the Transferable path, for the reasons above.
    var itemProvider: NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.json.identifier,
            visibility: .all
        ) { completion in
            completion(try? JSONEncoder().encode(self), nil)
            return nil
        }
        return provider
    }
}

/// A saved profile being dragged onto a native macOS Space (#7).
struct DraggableProfile: Codable, Transferable {
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
