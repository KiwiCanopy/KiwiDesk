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
/// mutating call on it, and `KeybindingMerge` — and, since a row
/// view writes through a holder named anything, every file declaring
/// a writable `[KeyBinding]` holder (`@Binding`, `Binding<…>`,
/// `inout`). A write through `.layers =` or a `KeyLayer(` built with
/// rows is outside both scans (profiles.md).
@Suite("Layer row writer census (#1807)")
struct LayerRowWriterCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    /// File → (writes, why it holds the rule).
    private static let writers: [String: (Int, String)] = [
        "KiwiDeskCore/Config/NavigationChords.swift":
            (1, "the dedupe itself"),
        "KiwiDeskCore/Config/SpaceShortcutRemoval.swift":
            (
                1,
                "drop: removes the rows naming a gone Space, adds"
                    + " none (#1827)"
            ),
        "KiwiDeskCore/Config/GuiConfig+Spaces.swift":
            (
                1,
                "rename: rewrites Lua in place, then takes the dedupe"
                    + " (driven)"
            ),
        "KiwiDesk/Settings/SettingsModel+LayerAdd.swift":
            (1, "import: merges, then takes the dedupe (driven)"),
        "KiwiDeskCore/Profiles/KiwiCore+ShortcutTopUp.swift":
            (
                1,
                "the digit, Desktop and generation top-ups' one"
                    + " append: adds only actions no profile binds"
                    + " (DigitTopUpOverrideTests,"
                    + " DesktopShortcutTopUpTests,"
                    + " DefaultShortcutGenerationTests)"
            ),
        "KiwiDesk/Settings/SettingsModel+LiveWrite.swift":
            (
                2,
                "draft adopts a top-up's rows: refuses an action the"
                    + " layer already runs (DesktopShortcutDraftTests);"
                    + " and an outside shortcut write's rows: one row per"
                    + " action by sameAction, the written chord taken"
                    + " from any other row (RuleKeepDraftTests)"
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
        "KiwiDesk/Settings/SettingsRevertRegister+Rules.swift":
            (
                1,
                "base revert (#2412): each row the switch moved swapped"
                    + " one for one for its saved row, adds none"
            ),
        "KiwiDesk/Settings/BindingRevertSet.swift":
            (
                1,
                "revert (#2412): an action's rows become exactly the"
                    + " saved ones, every action whose chord moved"
                    + " taken with it (BindingRevertSetTests)"
            ),
        "KiwiDesk/Settings/Components/Keybindings/"
            + "KeybindingCatalog+Layers.swift":
            (
                2,
                "layer rename: rewrites Lua in place, adds no row;"
                    + " layer delete: removes rows, adds none"
            ),
        "KiwiDesk/Settings/Components/Keybindings/"
            + "KeybindingCatalog+Lenses.swift":
            (
                3,
                "lens rename: drops a stale row of the new name, then"
                    + " rewrites Lua in place, adds no row; lens delete:"
                    + " removes rows, adds none (#2103,"
                    + " ShortcutsLensRowsTests)"
            ),
        "KiwiDesk/Shortcuts/ShortcutsReference.swift":
            (1, "shortcuts panel: removes rows from a copy it draws"),
        "KiwiDeskCore/Config/ShortcutBaseSwitch.swift":
            (
                1,
                "the Shortcuts use switch: rewrites a row's chord in"
                    + " place, adds no row, then takes the dedupe"
                    + " (#2460, ShortcutBaseSwitchTests)"
            ),
        "KiwiDeskCore/Config/KeyLayer.swift":
            (1, "the initializer"),
        "KiwiDeskCore/Profiles/RuleReachSnapshot+ShortcutBase.swift":
            (
                1,
                "a profile following the Shortcuts use switch: keeps a"
                    + " shared row its own row would replace at the new"
                    + " chord on the old one, the one chord that row"
                    + " has there (#2460, KeyLayerOverrideFollowTests)"
            ),
        "KiwiDesk/Settings/Components/KiwiVision/"
            + "KiwiVisionLensHeader.swift":
            (
                1,
                "a lens's header (#2103): the NavRow's binding setter,"
                    + " writing back the rows the row itself edited"
            ),
    ]

    /// File → (writable `[KeyBinding]` holders, why it holds the rule).
    private static let holders: [String: (Int, String)] = [
        "KiwiDesk/Settings/Components/Keybindings/KeybindingNavRow.swift":
            (
                1,
                "a catalog row: appends only when its action has no"
                    + " navigation row"
            ),
        "KiwiDesk/Settings/Components/Keybindings/Recorder/"
            + "RecorderCoordinator.swift":
            (1, "the recorder's steal: removes a combo from its holder"),
        "KiwiDesk/Settings/Components/Lua/AdvancedLuaGroup.swift":
            (
                2,
                "custom rows, which are no navigation action; the "
                    + "editor's body reaches one row's Lua by id (#2544)"
            ),
        "KiwiDesk/Settings/Components/Keybindings/KeybindingAppGroup.swift":
            (1, "application rows, which are no navigation action"),
        "KiwiDeskCore/Keys/KeybindingMerge.swift":
            (1, "the import merge; its caller takes the dedupe"),
        "KiwiDesk/Settings/Sections/ShortcutsSection.swift":
            (1, "the layer's rows handed down, written back whole"),
        "KiwiDesk/Settings/Components/Keybindings/KeybindingGroups.swift":
            (6, "catalog groups: hand the holder to their rows"),
        "KiwiDesk/Settings/Components/Keybindings/ShowHideGroup.swift":
            (1, "the Show & hide card: hands the holder to its rows"),
        "KiwiDesk/Settings/Components/Keybindings/KiwiHubKeyRows.swift":
            (1, "Show & hide ▸ KiwiHub: hands the holder to its rows"),
        "KiwiDesk/Settings/Components/Keybindings/"
            + "KiwiVisionKeyRows.swift":
            (1, "Show & hide ▸ KiwiVision: hands the holder to its rows"),
        "KiwiDesk/Settings/Components/Keybindings/"
            + "KiwiShelfKeyRows.swift":
            (1, "Show & hide ▸ KiwiShelf (#761): hands the holder on"),
        "KiwiDesk/Settings/Components/KiwiVision/"
            + "KiwiVisionLensHeader.swift":
            (
                1,
                "a lens's header (#2103): hands the base layer's rows"
                    + " to the lens's one NavRow"
            ),
        "KiwiDesk/Settings/Components/Keybindings/"
            + "OrphanedShortcutsGroup.swift":
            (1, "Inactive rows: hands the holder to its rows"),
        "KiwiDesk/Settings/Components/Keybindings/"
            + "DesktopShortcutsOffer.swift":
            (1, "an offer: hands the holder to its rows"),
        "KiwiDesk/Settings/Components/Keybindings/"
            + "TrackShortcutsOffer.swift":
            (1, "an offer: hands the holder to its rows"),
        "KiwiDesk/Settings/Sections/LayersCard.swift":
            (1, "the layer card: hands the holder to its rows"),
    ]

    private static let holderPattern = try! NSRegularExpression(
        pattern:
            #"Binding<\[KeyBinding\]>"#
            + #"|@Binding\s+var\s+\w+\s*:\s*\[KeyBinding\]"#
            + #"|inout\s+\[KeyBinding\]"#
    )

    private static let pattern = try! NSRegularExpression(
        pattern: #"\.bindings(\[[^\]]*\])?\s*(=(?!=)|\+=)"#
            + #"|\.bindings\.(append|insert|remove\w*|replaceSubrange)\b"#
            + #"|KeybindingMerge\.(merge|upsert)\("#
    )

    /// File → matches of `regex` over both trees, comments stripped.
    private func scan(
        _ regex: NSRegularExpression
    ) throws -> [String: Int] {
        var found: [String: Int] = [:]
        for tree in ["KiwiDeskCore", "KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: Self.root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty)
            for file in files {
                let text = try SourceScan.strippedSource(at: file)
                let hits = regex.numberOfMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text)
                )
                if hits > 0 {
                    let key = String(
                        file.path.dropFirst(Self.root.path.count + 1)
                    )
                    found[key] = hits
                }
            }
        }
        #expect(!found.isEmpty)
        return found
    }

    @Test("every writable row holder is classified")
    func holdersAreClassified() throws {
        let found = try scan(Self.holderPattern)
        #expect(
            found == Self.holders.mapValues(\.0),
            "unclassified or moved: \(found.sorted { $0.key < $1.key })"
        )
    }

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
