import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A lens's binding is named and classified like every catalog
/// row (#2103, #2111): the one naming door speaks its locale, an
/// imported toggle is a navigation row, and the surfaces that list
/// lens rows take the lens lists they owe — Settings the stored
/// one (ruling 40), the overview and the chips the live one.
@Suite("Shortcuts ▸ lens naming and wiring", .serialized)
@MainActor
struct ShortcutsLensNamingTests {
    private var binding: KeyBinding {
        KeyBinding(
            combo: "control+option+w",
            lua: KeybindingCatalog.toggleLens("Writing").lua,
            kind: .navigation,
            label: "Toggle Writing lens"
        )
    }

    @Test("the naming door speaks a lens row in the page's locale")
    func doorNamesTheLens() {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select("en") }
        var config = GuiConfig()
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: [binding])
        ]
        #expect(
            KeybindingCatalog.localizedName(of: binding, config: config)
                == "Linse „Writing“ umschalten"
        )
    }

    @Test("an imported lens toggle is a navigation row")
    func importClassifiesTheLens() {
        LocalizationManager.shared.select("en")
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "control+option+w",
                        lua: KeybindingCatalog.toggleLens("Writing").lua,
                        kind: .custom
                    )
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.layers[0].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Toggle Writing lens")
    }

    /// A binding naming a lens no store holds still draws a row,
    /// and a stored lens's row owns every spelling of it, so no
    /// chord is hidden whichever layer holds it.
    @Test("every bound lens draws a row that owns its spellings")
    func boundLensesDrawRows() {
        let bindings = [
            KeyBinding(
                combo: "control+w",
                lua: KeybindingCatalog.toggleLens("writing").lua,
                kind: .navigation
            ),
            KeyBinding(
                combo: "control+g",
                lua: KeybindingCatalog.toggleLens("Gone").lua,
                kind: .navigation
            ),
        ]
        #expect(
            KeybindingCatalog.lensOffer(
                stored: ["Writing", "Mail"],
                bindings: bindings
            ) == ["Writing", "Mail", "Gone"]
        )
        // The stored lens's row owns the other spelling, so its
        // chord in any layer is the row's.
        let row = KeybindingCatalog.toggleLens("Writing")
        #expect(row.runs(bindings[0].lua))
        #expect(!row.runs(bindings[1].lua))
        #expect(!row.runs(KeybindingCatalog.toggleKiwiVision.lua))
        #expect(
            KeybindingCatalog.toggleKiwiVision.runs(
                KeybindingCatalog.toggleKiwiVision.lua
            )
        )
    }

    @Test("a chip's chord matches its lens however it is spelled")
    func chordMatchesAnySpelling() {
        #expect(KeybindingCatalog.names(binding, "WRITING"))
        #expect(!KeybindingCatalog.names(binding, "Draft"))
        #expect(
            ShortcutsOpenBinding.lensCombo(in: [binding], lens: "WRITING")
                == KeyCombo.parse("control+option+w")
        )
        #expect(
            ShortcutsOpenBinding.lensCombo(in: [binding], lens: "Draft")
                == nil
        )
    }

    private func flat(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
        ).filter { !$0.isWhitespace }
    }

    /// A row finds, records and preflights its binding through the
    /// row's own ownership, never an exact-Lua compare beside it.
    @Test("a row matches its bindings through what it owns")
    func rowMatchesThroughRuns() throws {
        let row = try flat(
            "Sources/KiwiDesk/Settings/Components/Keybindings/"
                + "KeybindingNavRow.swift"
        )
        #expect(row.occurrences(of: "command.runs($0.lua)") == 3)
        #expect(!row.contains("$0.lua==command.lua"))
    }

    /// Each surface hands its lens list in; a default would let a
    /// dropped argument draw no lens rows with every test green.
    @Test("each surface hands in the lens list it owes")
    func surfacesHandInTheirLenses() throws {
        #expect(
            try flat(
                "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
            )
            .contains(
                "lenses:KeybindingCatalog.lensOffer("
                    + "stored:model.core.kiwiVisionStoredLensNames,"
                    + "bindings:model.config.layers.flatMap(\\.bindings))"
            )
        )
        #expect(
            try flat(
                "Sources/KiwiDesk/Jump/JumpPanelController+Shortcuts.swift"
            )
            .contains("lenses:core.kiwiVisionLensChoices.map(\\.name)")
        )
        #expect(
            try flat("Sources/KiwiDesk/Jump/JumpPanelController+View.swift")
                .contains(
                    "ShortcutsOpenBinding.lensGlyphs(core:core,lens:$0)"
                )
        )
    }
}
