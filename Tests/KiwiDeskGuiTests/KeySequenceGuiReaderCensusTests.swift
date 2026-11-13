import Foundation
import Testing

/// Every read of a layer's flat rows in the GUI tree is classified
/// by what it does with a key sequence (#1871), as
/// `KeySequenceReaderCensusTests` does for Core: a reader that
/// registers or runs rows takes `KeyLayer.pressBindings`, one that
/// asks what an action does takes `actionBindings`, one rewriting an
/// action takes `mappingActions`, and the rest carry a sequence
/// whole. A new reader reds here until it is classified; the
/// partition's own spellings are outside the scan. Trade: the
/// needle sees a `.bindings` read only, so a reader handed a
/// layer's rows as a `[KeyBinding]` value or binding (the Key
/// sequences card's subtree, `NavRow`'s caption) is review's.
@Suite("Key sequence GUI reader census (#1871)")
struct KeySequenceGuiReaderCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    /// File under `Sources/KiwiDesk` → (reads, why a sequence row
    /// is right there).
    private static let readers: [String: (Int, String)] = [
        "Onboarding/OnboardingKeys+Chords.swift":
            (2, "chord by Lua: a leader's empty Lua never matches"),
        "Onboarding/OnboardingKeys+Toggles.swift":
            (1, "chord by Lua: an end key is no chord to teach"),
        "Settings/BindingRevertSet.swift":
            (2, "↺ walks press rows; a sequence reverts whole"),
        "Settings/Components/Keybindings/KeybindingCatalog+DisplayName.swift":
            (
                2,
                "the naming roster's Desktops; a sequence is named by its "
                    + "label"
            ),
        "Settings/Components/Keybindings/KeybindingCatalog+Lenses.swift":
            (2, "a lens's chord is a press row; rewrites take mappingActions"),
        "Settings/Components/Keybindings/KeyboardCensus.swift":
            (3, "the board draws chords: a leader holds its key"),
        "Settings/Components/Keybindings/KeyboardHoverReading.swift":
            (1, "conflicts judge a leader's chord as a row's"),
        "Settings/Components/Keybindings/Sequences/"
            + "SequenceNodeRow+Recorder.swift":
            (1, "the card's own rows: a leader judged by its chord"),
        "Settings/Components/Keybindings/ShortcutsFamilyRows+Draft.swift":
            (1, "Desktops and lenses the rows offer; a leader runs neither"),
        "Settings/Components/Keybindings/ShortcutsGates.swift":
            (1, "the Lua drawer lists .custom rows; a sequence is none"),
        "Settings/Components/KiwiVision/KiwiVisionLensHeader.swift":
            (3, "lens chord by Lua; the default layer's rows ride whole"),
        "Settings/Components/Simple/SimpleCoverage.swift":
            (1, "an Open application row by kind: a sequence is none"),
        "Settings/Components/Simple/SimpleKiwiHubKeys.swift":
            (1, "KiwiHub's chord by Lua: a leader never matches"),
        "Settings/Components/Simple/SimpleShortcutCards.swift":
            (2, "the apps card's rows: a sequence rides whole"),
        "Settings/HomeCardPreview.swift":
            (1, "key caps of chords: a leader is a chord"),
        "Settings/Sections/ShortcutsSection.swift":
            (2, "the page's editable rows: a sequence rides whole"),
        "Settings/SettingsModel+AppWide.swift":
            (1, "sided chords: a leader keeps a side as a row does"),
        "Settings/SettingsModel+LayerPass.swift":
            (1, "the base pass keeps rows by chord: a sequence whole"),
        "Settings/SettingsModel+LayerReach.swift":
            (1, "sameRows compares a sequence's whole tree"),
        "Settings/SettingsModel+LayerReachEdit.swift":
            (2, "a delete counts the layer's own rows whole"),
        "Settings/SettingsModel+LiveWrite.swift":
            (4, "a written chord takes a leader's chord as a row's"),
        "Settings/SettingsModel+Reset.swift":
            (5, "reset keeps a sequence unless the seed takes its leader"),
        "Settings/SettingsModel+ShortcutRestoreReach.swift":
            (
                4,
                "restore keying (#3248): local copies of the default"
                    + " layer keyed for the reach; a sequence keys by its"
                    + " leader like any row"
            ),
        "Settings/SettingsModel+RevealLanding.swift":
            (1, "a reveal finds a sequence by id: its card"),
        "Settings/SettingsModel+Root.swift":
            (1, "Simple's hidden Lua rows by kind: a sequence is none"),
        "Settings/SettingsModel+ShortcutBase.swift":
            (4, "a leader left on ⌃⌥ is listed by its chord"),
        "Settings/SettingsRevertRegister+Rules.swift":
            (3, "the base revert takes a leader's saved spelling alone"),
        "Settings/SettingsValueReadout+ShortcutsGlyphs.swift":
            (1, "the naming roster's Desktops: a leader names none"),
        "Shortcuts/KeySequenceHintController.swift":
            (1, "the running sequence appended whole for its hint"),
        "Shortcuts/ShortcutsOpenBinding.swift":
            (1, "an opener's chord by Lua: a leader never matches"),
        "Shortcuts/ShortcutsReference+Bands.swift":
            (3, "build() strips sequences first: press rows alone"),
        "Shortcuts/ShortcutsReference+PocketApps.swift":
            (1, "build() strips sequences first: press rows alone"),
        "Shortcuts/ShortcutsReference.swift":
            (4, "strips openers; sequences list by path (#1871)"),
    ]

    /// A `.bindings` read, not a `bindings(for:)` call.
    private static let pattern = try! NSRegularExpression(
        pattern: #"\.bindings\b(?!\s*\()"#
    )

    @Test("every GUI reader of a layer's rows is classified")
    func readersAreClassified() throws {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("KiwiDesk")
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
                let base = Self.root.appendingPathComponent("KiwiDesk").path
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
