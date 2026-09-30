import Foundation
import Testing

/// Every write to a layer's rows, in both trees, is classified: it
/// takes `NavigationChords`, is driven by
/// `NavigationChordWriterTests`, or says why it cannot give a
/// navigation action a second chord (#1807, profiles.md ▸ A
/// navigation action holds one chord per layer). A new writer reds
/// here until it is classified.
///
/// Scope: an assignment to `.bindings` (whole or by index), a
/// mutating call on it, and `KeybindingMerge`. A write through
/// `.layers =` or an element's own field is not a row write.
@Suite("Layer row writer census (#1807)")
struct LayerRowWriterCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    /// File → (writes, why it holds the rule).
    private static let writers: [String: (Int, String)] = [
        "KiwiDeskCore/Config/NavigationChords.swift":
            (1, "the dedupe itself"),
        "KiwiDeskCore/Config/GuiConfig.swift":
            (
                1,
                "rename: rewrites Lua in place, then takes the dedupe"
                    + " (driven)"
            ),
        "KiwiDesk/Settings/SettingsModel+Refresh.swift":
            (1, "import: merges, then takes the dedupe (driven)"),
        "KiwiDeskCore/Profiles/KiwiCore+StarterRescale.swift":
            (
                1,
                "top-up: adds only actions no profile binds"
                    + " (DigitTopUpOverrideTests)"
            ),
        "KiwiDesk/Settings/SettingsModel+Reset.swift":
            (
                1,
                "reset: drops every user row on a shipped verb"
                    + " (driven)"
            ),
        "KiwiDeskCore/App/KiwiCore+GuiConfigSeed.swift":
            (1, "first-run seed: one row per action by construction"),
        "KiwiDeskCore/Config/RuleReach+Keys.swift":
            (
                3,
                "key reach: an action's rows become exactly the"
                    + " draft's, after removing every row of that action"
            ),
        "KiwiDesk/Settings/Sections/ShortcutsSection.swift":
            (1, "layer editor: writes back the rows it was handed"),
        "KiwiDesk/Settings/SettingsModel+LiveApply.swift":
            (
                1,
                "live session copy: mirrors a draft row by id so its"
                    + " recording registers at once; never persisted"
            ),
        "KiwiDesk/Settings/Components/Keybindings/"
            + "KeybindingCatalog+Layers.swift":
            (1, "layer rename: rewrites Lua in place, adds no row"),
        "KiwiDesk/Shortcuts/ShortcutsReference.swift":
            (1, "shortcuts panel: removes rows from a copy it draws"),
        "KiwiDeskCore/Config/KeyLayer.swift":
            (1, "the initializer"),
    ]

    private static let pattern = try! NSRegularExpression(
        pattern: #"\.bindings(\[[^\]]*\])?\s*(=(?!=)|\+=)"#
            + #"|\.bindings\.(append|insert|remove\w*|replaceSubrange)\b"#
            + #"|KeybindingMerge\.(merge|upsert)\("#
    )

    @Test("every layer row writer is classified")
    func writersAreClassified() throws {
        var found: [String: Int] = [:]
        for tree in ["KiwiDeskCore", "KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty)
            for file in files {
                let text = try SourceScan.strippedSource(at: file)
                let hits = Self.pattern.numberOfMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text)
                )
                if hits > 0 {
                    found[
                        String(file.path.dropFirst(Self.root.path.count + 1))
                    ] = hits
                }
            }
        }
        #expect(!found.isEmpty)
        #expect(
            found == Self.writers.mapValues(\.0),
            "unclassified or moved: \(found.sorted { $0.key < $1.key })"
        )
    }
}
