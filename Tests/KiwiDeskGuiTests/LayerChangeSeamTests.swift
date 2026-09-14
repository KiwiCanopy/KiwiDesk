import Foundation
import Testing

@testable import KiwiDesk

/// The `layer_change` event's seams (#1168), by source scan —
/// the behaviour half is `LayerChangeEventTests` in the Core
/// target. Two things a behaviour test cannot see: that every
/// switch site in the manager announces through ONE door, so a
/// site emitting beside its switch cannot report a change the
/// others do not; and that Core's bootstrap is what wires the
/// seam to the emitter, since a seam nothing wires is a green
/// suite over an event that never leaves the process.
@Suite("layer_change seams")
struct LayerChangeSeamTests {
    private func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(path)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(!text.isEmpty, Comment(rawValue: path))
        return text
    }

    @Test("every switch site announces through the one door")
    func oneAnnouncement() throws {
        let manager = try squashed(
            "Sources/KiwiDeskCore/Keys/KeybindingManager.swift"
        )
        // Three switch sites (switch, reset, replace) and the
        // one definition.
        #expect(manager.occurrences(of: "announce(from:") == 4)
        // The two hooks are FIRED only inside that door.
        #expect(manager.occurrences(of: "onLayerSwitched(") == 1)
        #expect(manager.occurrences(of: "onLayerChange(") == 1)
        #expect(
            manager.contains(
                "privatefuncannounce(from:String,to:String){"
                    + "onLayerChange(to)"
                    + "iffrom!=to{onLayerSwitched(from,to)}}"
            )
        )
    }

    @Test("Core wires the seam to the emitter, once")
    func bootstrapWiresTheSeam() throws {
        let bootstrap = try squashed(
            "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
        )
        #expect(
            bootstrap.contains(
                "keys.onLayerSwitched={[weakself]from,toin"
                    + "self?.emitLayerChange(from:from,to:to)}"
            )
        )
        // …and nowhere else in Core: the GUI owns the sibling
        // `onLayerChange` hook, Core owns this one.
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var writers = 0
        for file in try SourceScan.swiftSources(under: root) {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            writers += text.occurrences(of: "onLayerSwitched=")
        }
        #expect(writers == 1)
    }
}
