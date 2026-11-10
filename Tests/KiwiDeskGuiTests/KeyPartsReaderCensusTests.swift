import Foundation
import Testing

/// Every `keyParts(` read of a key reach table key, in both trees, is
/// classified by what it does with a key sequence's key (#3124): a
/// sequence is keyed by its layer and leader, so its action slot
/// carries a mark and its leader rather than Lua. A reader takes the
/// layer, compares the slot to a Lua the mark can never equal, or
/// asks `RuleReach+KeySequences` first; a new reader reds here until
/// it is classified. Trade: the needle sees the call alone, so a key
/// split by hand on the separator is review's.
@Suite("Key parts reader census (#3124)")
struct KeyPartsReaderCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    /// File → (reads, why a sequence key is read right there).
    private static let readers: [String: (Int, String)] = [
        "KiwiDeskCore/Config/RuleReach+Keys.swift":
            (
                4,
                "the declaration, rivals by layer, and setRows, which"
                    + " branches on leader(of:) first"
            ),
        "KiwiDeskCore/Config/RuleReach+KeySequences.swift":
            (2, "the seam itself: leader(of:) and the layer it writes"),
        "KiwiDeskCore/Config/RuleReach+KeyRivals.swift":
            (2, "the layer only; chords read through chord(of:value:)"),
        "KiwiDeskCore/Commands/KiwiCore+ShortcutCommands.swift":
            (
                4,
                "layers, and rows(of:), which skips a sequence key"
                    + " (ShortcutSequenceCommandsTests)"
            ),
        "KiwiDesk/Settings/SettingsModel+ShortcutRevert.swift":
            (1, "a reach row's binding; a sequence key is guarded out"),
        "KiwiDesk/Settings/SettingsModel+RowRevert.swift":
            (1, "a reach row's ↺; a sequence key is guarded out"),
        "KiwiDesk/Settings/SettingsModel+LiveWrite.swift":
            (1, "an outside write; a sequence key lands whole first"),
        "KiwiDesk/Settings/SettingsModel+RuleReachEdit.swift":
            (1, "the layer only"),
        "KiwiDesk/Settings/SettingsModel+RuleReachDiff.swift":
            (1, "keyName's last fallback, after a leader is named"),
        "KiwiDesk/Settings/SettingsModel+Lenses.swift":
            (2, "compares to a lens toggle's Lua, which no mark equals"),
        "KiwiDesk/Settings/LayerRowPicks.swift":
            (
                4,
                "layers, and a switch row's Lua, which no mark equals;"
                    + " a rename rebuilds the key with its slot whole"
            ),
        "KiwiDesk/Settings/Components/AppRules/RuleReachChecklist.swift":
            (1, "the layer only"),
    ]

    @Test("every keyParts reader in both trees is classified")
    func readersAreClassified() throws {
        var found: [String: Int] = [:]
        for tree in ["KiwiDeskCore", "KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty)
            for file in files {
                let text = try SourceScan.strippedSource(at: file)
                let hits =
                    text.components(separatedBy: "keyParts(")
                    .count - 1
                guard hits > 0 else { continue }
                let path = String(
                    file.path.dropFirst(Self.root.path.count + 1)
                )
                found[path] = hits
            }
        }
        #expect(!found.isEmpty)
        #expect(
            found == Self.readers.mapValues(\.0),
            "unclassified or moved: \(found.sorted { $0.key < $1.key })"
        )
    }
}
