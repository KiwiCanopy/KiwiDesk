import Foundation
import Testing

@testable import KiwiDesk

/// The `layer_change` event's seams (#1168), by source scan —
/// the behaviour half is `LayerChangeEventTests` in the Core
/// target. What a behaviour test cannot see: the manager fires
/// its seam from ONE door, Core's bootstrap is the seam's one
/// writer, and the GUI reads the event off the bus rather than
/// taking a hook of its own — a second hook is the second seam
/// for one fact this shape retired.
@Suite("layer_change seams")
struct LayerChangeSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func squashed(_ path: String) throws -> String {
        let text = SourceScan.stripComments(
            try String(
                contentsOf: Self.root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(!text.isEmpty, Comment(rawValue: path))
        return text
    }

    private func writers(
        of needle: String,
        under directory: String
    ) throws -> Int {
        var count = 0
        for file in try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(directory)
        ) {
            count += SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            .occurrences(of: needle)
        }
        return count
    }

    /// The seam is FIRED in one place, so a switch site cannot
    /// report a change the others do not.
    @Test("the manager fires its seam from one door")
    func oneDoor() throws {
        let manager = try squashed(
            "Sources/KiwiDeskCore/Keys/KeybindingManager.swift"
        )
        #expect(manager.occurrences(of: "onLayerChange(") == 1)
    }

    /// One writer in production, and it is the emitter's; the
    /// GUI's indicator is a bus sink keyed on the event.
    @Test("Core wires the seam to the emitter, and nothing else")
    func oneWriter() throws {
        let bootstrap = try squashed(
            "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
        )
        #expect(
            bootstrap.contains(
                "keys.onLayerChange={[weakself]from,toin"
                    + "self?.emitLayerChange(from:from,to:to)}"
            )
        )
        #expect(
            try writers(of: "onLayerChange=", under: "Sources") == 1
        )
        let app = try squashed("Sources/KiwiDesk/AppDelegate.swift")
        #expect(app.contains("guardevent==.layerChange,"))
        #expect(!app.contains("onLayerChange"))
    }
}
