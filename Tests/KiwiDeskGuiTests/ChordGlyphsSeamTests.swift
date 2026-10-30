import Foundation
import Testing

/// Every chord the GUI draws reaches `ComboSymbols` through
/// `ChordGlyphs`, which names a side in words (#2601): a direct
/// call draws Core's `L⌃L⌥J` letters on screen. `allowed` is the one
/// copy of who may read Core's lettered form, each for its reason.
@Suite("Chord glyphs have one door (#2601)")
struct ChordGlyphsSeamTests {
    private static let allowed: [String: (count: Int, why: String)] = [
        "ChordGlyphs.swift": (5, "the door itself")
    ]

    @Test("ComboSymbols is drawn only through ChordGlyphs")
    func oneDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        var counts: [String: Int] = [:]
        for file in files {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            // The member names without a call's paren: a function
            // reference or a line break before `(` still counts.
            let calls = ["render", "modifierSymbols", "sideLetter"]
                .map {
                    text.components(separatedBy: "ComboSymbols.\($0)")
                        .count - 1
                }
                .reduce(0, +)
            if calls > 0 { counts[file.lastPathComponent] = calls }
        }
        #expect(counts == Self.allowed.mapValues(\.count))
    }
}
