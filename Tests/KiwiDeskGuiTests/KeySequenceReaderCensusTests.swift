import Foundation
import Testing

/// Every read of a layer's flat rows in Core is classified by what
/// it does with a key sequence (#1871): a `.sequence` row is no
/// press row, so a reader that registers or runs rows takes
/// `KeyLayer.pressBindings`, one that asks what an action does takes
/// `actionBindings`, and the rest carry a sequence whole. A new
/// reader reds here until it is classified. The partition's own
/// spellings (`pressBindings`, `actionBindings`, `sequences`) are
/// outside the scan: taking one IS the classification.
@Suite("Key sequence reader census (#1871)")
struct KeySequenceReaderCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    /// File → (reads, why a sequence row is right there).
    private static let readers: [String: (Int, String)] = [
        "KiwiDeskCore/App/ConfigIssues.swift":
            (1, "names the file holding a chord: a leader is a chord"),
        "KiwiDeskCore/App/KiwiCore+GuiConfigSeed.swift":
            (2, "first-run seed: an empty test, then the seed's write"),
        "KiwiDeskCore/App/KiwiCore+LiveKeybindings.swift":
            (1, "meta by chord: a leader's own meta, by its chord"),
        "KiwiDeskCore/App/KiwiCore+StructuredKeybindings.swift":
            (
                2,
                "the install's own tuples: press rows prepared, then"
                    + " the sequences built (KeySequenceInstallTests)"
            ),
        "KiwiDeskCore/Commands/KiwiCore+ShortcutCommands.swift":
            (1, "shortcut.list: an entry carries its steps whole"),
        "KiwiDeskCore/Config/DesktopBindingsFile.swift":
            (1, "a MachineConfig destination case, no layer"),
        "KiwiDeskCore/Config/MachineConfig.swift":
            (1, "a MachineConfig destination case, no layer"),
        "KiwiDeskCore/Config/MachineFile+NewerFormat.swift":
            (1, "a MachineConfig destination case, no layer"),
        "KiwiDeskCore/Config/KeyBinding+Sequence.swift":
            (1, "the partition door's own rewrite"),
        "KiwiDeskCore/Config/KeyLayer.swift":
            (1, "the initializer"),
        "KiwiDeskCore/Config/KeyLayerOverride+Codable.swift":
            (1, "an override's emptiness: a sequence is a row"),
        "KiwiDeskCore/Config/KeyLayerOverride.swift":
            (
                7,
                "resolve and diff by combo: a profile holds or"
                    + " overrides a whole sequence (KeySequenceReaderTests"
                    + " ▸ overrideIsWhole)"
            ),
        "KiwiDeskCore/Config/NavigationChords.swift":
            (2, "the dedupe: it groups navigation rows alone"),
        "KiwiDeskCore/Config/RuleReach+Keys.swift":
            (
                7,
                "key reach keys rows by Lua, so a sequence rides the"
                    + " resolve whole, and sameShortcuts reads its tree"
                    + " (KeySequenceReaderTests ▸ shapeSeesSteps)"
            ),
        "KiwiDeskCore/Config/ShortcutBaseSwitch.swift":
            (3, "the base switch moves a leader's chord with the rest"),
        "KiwiDeskCore/Config/SpaceShortcutRemoval.swift":
            (
                2,
                "an override's emptiness after the drop, which trims"
                    + " end keys (KeySequenceReaderTests)"
            ),
        "KiwiDeskCore/Keys/KeybindingConflicts.swift":
            (2, "a leader is judged by its chord, both ways"),
        "KiwiDeskCore/Keys/KeybindingMerge.swift":
            (2, "re-import upserts a sequence whole by its leader"),
        "KiwiDeskCore/Profiles/KiwiCore+ShortcutTopUp.swift":
            (
                7,
                "top-ups judge chords free and actions by Lua: a"
                    + " leader holds its chord, an end key is a separate"
                    + " trigger (design-decisions ▸ #1871 amendment)"
            ),
        "KiwiDeskCore/Profiles/KiwiCore+SpaceShortcutDrop.swift":
            (1, "names(_:) walks a sequence's end keys"),
        "KiwiDeskCore/Profiles/RuleReachSnapshot+ShortcutBase.swift":
            (2, "a profile following the base switch, by chord"),
    ]

    /// A `.bindings` read, not the manager's `bindings(for:)`.
    private static let pattern = try! NSRegularExpression(
        pattern: #"\.bindings\b(?!\s*\()"#
    )

    @Test("every Core reader of a layer's rows is classified")
    func readersAreClassified() throws {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("KiwiDeskCore")
        )
        #expect(!files.isEmpty)
        var found: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let hits = Self.pattern.numberOfMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
            if hits > 0 {
                found[String(file.path.dropFirst(Self.root.path.count + 1))] =
                    hits
            }
        }
        #expect(!found.isEmpty)
        #expect(
            found == Self.readers.mapValues(\.0),
            "unclassified or moved: \(found.sorted { $0.key < $1.key })"
        )
    }

    @Test("the hotkey install reads press rows alone")
    func installTakesPressRows() throws {
        let text = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "KiwiDeskCore/App/KiwiCore+StructuredKeybindings.swift"
            )
        )
        #expect(text.contains("layer.pressBindings.enumerated()"))
        #expect(text.contains("prepareSequences(layer, lua: lua)"))
    }
}
