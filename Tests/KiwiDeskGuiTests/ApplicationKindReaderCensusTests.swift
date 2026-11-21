import Foundation
import Testing

/// Every comparison against `KeyBinding.Kind.application` in the GUI
/// tree is classified by what it does with an Apple Shortcut row
/// (#3526), which is filed as `.application` too: a reader meaning
/// "an app row" asks `AppleShortcutAction.isAppRow`, never the kind
/// alone. A new comparison reds here until it is classified. Trade:
/// the needle sees `== .application` and `!= .application` only, so
/// a `switch` arm or a filter by key path is review's.
@Suite("Application kind reader census (#3526)")
struct ApplicationKindReaderCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    /// File under `Sources/KiwiDesk` → (comparisons, why an Apple
    /// Shortcut row is safe there).
    private static let readers: [String: (Int, String)] = [
        "Settings/Components/Keybindings/AppleShortcutAction.swift":
            (1, "isAppRow itself: the kind and no shortcut Lua"),
        "Settings/Components/Keybindings/KeybindingCatalog+Apps.swift":
            (1, "takenActions keys by bundle id: a shortcut has none"),
        "Settings/Components/Keybindings/KeybindingAppGroup+AddRow.swift":
            (1, "fullyBoundBundleIDs keys by bundle id, as above"),
        "Settings/Components/Keybindings/Sequences/"
            + "SequenceActionMenu+Trigger.swift":
            (2, "app icon by bundle id; the shortcut face before it"),
        "Settings/Components/Keybindings/Sequences/SequenceTree.swift":
            (1, "appKey keeps an app action only by its parse"),
        "Settings/Components/Gestures/GestureListWords.swift":
            (1, "a gesture's name: the shortcut's name read first"),
        "Settings/SettingsValueReadout+ShortcutsGlyphs.swift":
            (1, "a row's label: the shortcut's name read first"),
        "Shortcuts/ShortcutsReference+Gestures.swift":
            (1, "a gesture badge's app by bundle id: none for one"),
    ]

    private static let pattern = try! NSRegularExpression(
        pattern: #"[!=]=\s*\.application\b"#
    )

    @Test("every .application comparison is classified")
    func readersAreClassified() throws {
        let files = try SourceScan.swiftSources(under: Self.root)
        #expect(!files.isEmpty)
        var found: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let hits = Self.pattern.numberOfMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
            if hits > 0 {
                let base = Self.root.path
                found[String(file.path.dropFirst(base.count + 1))] = hits
            }
        }
        #expect(!found.isEmpty)
        #expect(
            found == Self.readers.mapValues(\.0),
            "unclassified or moved: \(found.sorted { $0.key < $1.key })"
        )
    }
}
