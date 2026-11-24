import Foundation
import Testing

/// Every production call of a default-row producer names the undo
/// key (#3599, profiles.md ▸ the undo pair seeds by letter). The
/// producers default it to the US `z` for the tests, whose cores pin
/// a US board, so a writer that leaves it out compiles, seeds the US
/// position on a QWERTZ Mac and reds no behavioural suite.
///
/// Scope: a call spelled as one of `producers`, both trees,
/// comments and literals stripped; a call reached through a
/// renamed reference is outside it. `luaOnly` names the calls that
/// read only `.lua`, where the key cannot matter.
@Suite("Undo key seed census (#3599)")
struct UndoKeySeedCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    /// The producers' call spellings; `rows` counts only as
    /// `rows(ofGeneration:`.
    private static let producers = [
        "DefaultKeybindings.bindings", "generationTopUp", "rows",
    ]

    /// File → calls whose rows are read for their `.lua` alone.
    private static let luaOnly: [String: Int] = [
        "KiwiDeskCore/Profiles/KiwiCore+ShortcutTopUp.swift": 1
    ]

    @Test("every producer call names the undo key")
    func callsNameTheKey() throws {
        var unnamed: [String: Int] = [:]
        var seen = 0
        for tree in ["KiwiDeskCore", "KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty)
            for file in files {
                let text = Array(try SourceScan.strippedSource(at: file))
                let key = String(
                    file.path.dropFirst(Self.root.path.count + 1)
                )
                for args in Self.arguments(in: text) {
                    seen += 1
                    if !args.contains("undoKey:") {
                        unnamed[key, default: 0] += 1
                    }
                }
            }
        }
        // Vacuity: the three writers and the `.lua` read.
        #expect(seen >= 4)
        #expect(unnamed == Self.luaOnly, "unnamed: \(unnamed)")
    }

    /// The argument lists of every producer call in `text`, a
    /// declaration (`func …(`) left out.
    private static func arguments(in text: [Character]) -> [String] {
        var found: [String] = []
        for producer in producers {
            for site in SourceScan.callSites(in: text, for: producer) {
                guard var cursor = site.paren else { continue }
                let lead = text[max(0, site.start - 5)..<site.start]
                if String(lead) == "func " { continue }
                guard
                    let args = SourceScan.balanced(
                        text,
                        from: &cursor,
                        open: "(",
                        close: ")"
                    )
                else { continue }
                let head = args.trimmingCharacters(in: .whitespacesAndNewlines)
                if producer == "rows", !head.hasPrefix("ofGeneration") {
                    continue
                }
                found.append(args)
            }
        }
        return found
    }
}
