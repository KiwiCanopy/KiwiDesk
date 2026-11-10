import Foundation
import Testing

/// The search match path's purity (spec 11a), split from
/// `SettingsSearchIndexTests` at the file ceiling.
@Suite("Settings search match path")
struct SettingsSearchMatchPathTests {

    /// Spec 11a's hard line, as a source scan: the match path —
    /// the index, the builder, the synonyms — never touches the
    /// value readout, the palette store, AX or the filesystem.
    /// Enrichment happens in the ROW view, per visible row, and
    /// the context is collected by the header bar from memory.
    @Test("the match path stays off enrichment and disk")
    func matchPathStaysPure() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let searchCore = [
            "Sources/KiwiDesk/Settings/SettingsSearch.swift",
            "Sources/KiwiDesk/Settings/SettingsSearchIndex.swift",
            "Sources/KiwiDesk/Settings/SettingsSearchSynonyms.swift",
        ]
        let forbidden = [
            "SettingsValueReadout",
            "PaletteStore",
            "AXHelper",
            "FileManager",
            "Data(contentsOf",
        ]
        for path in searchCore {
            let url = root.appendingPathComponent(path)
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            for needle in forbidden {
                #expect(
                    !source.contains(needle),
                    "\(path) touches \(needle)"
                )
            }
        }
    }
}
