import Foundation
import Testing

/// A gesture reach key is read through `LayerGestureKey` alone
/// (#3535): a bare `GestureKey(spelling:` beside it reads the
/// default layer's keys and silently drops every other layer's.
/// The map's own decoder and the layer key's parse are the one
/// pair of homes.
@Suite("Gesture key spelling door (#3535)")
struct GestureKeySpellingDoorTests {
    private static let allowed: Set<String> = [
        "KiwiDeskCore/Config/GestureMap+Coding.swift",
        "KiwiDeskCore/Config/LayerGestures.swift",
    ]

    @Test("only the map's decoder and the layer key parse a spelling")
    func oneDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        let prefix = root.path + "/"
        var homes: Set<String> = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let bare = source.replacingOccurrences(
                of: "LayerGestureKey(spelling:",
                with: ""
            )
            guard bare.contains("GestureKey(spelling:") else { continue }
            homes.insert(String(file.path.dropFirst(prefix.count)))
        }
        #expect(!homes.isEmpty)
        #expect(
            homes == Self.allowed,
            Comment(rawValue: "spelling read in \(homes.sorted())")
        )
    }
}
