import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The "Shortcuts use" switch in the draft (#2460): it stages the
/// rows and the base together, the save pill narrates it as one row,
/// and the rows it leaves on `⌃⌥` are listed with their reasons.
@Suite("Shortcut base switch in Settings (#2460)")
@MainActor
struct ShortcutBaseSwitchModelTests {
    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation, label: "")
    }

    private func model(_ rows: [KeyBinding]) -> SettingsModel {
        let model = makeTestModel(core: makeTestCore())
        var config = GuiConfig()
        config.spaces = [SpaceID(1)]
        config.layers = [KeyLayer(name: KeyLayer.defaultName, bindings: rows)]
        model.config = config
        model.cleanConfig = config
        return model
    }

    private var seed: [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: [SpaceID(1)],
            resizeStep: 50,
            base: .standard
        )
    }

    @Test("the switch stages every row and the base")
    func switchStages() {
        let model = model(seed)
        model.setShortcutBase(.hyper)
        #expect(model.config.shortcutBase == .hyper)
        #expect(
            model.config.layers[0].bindings
                == seed.map(ShortcutBase.hyper.rebased)
        )
        #expect(model.draftUsesHyper)
    }

    /// One control, one change in the pill (#2456): the rows the
    /// switch moved are its own row's, and a separate edit still
    /// lists beside it.
    @Test("the pill narrates the switch as one row")
    func pillHasOneRow() {
        let model = model(seed)
        model.setShortcutBase(.hyper)
        let old = model.cleanConfig
        var new = model.config
        #expect(
            SettingsValueReadout.shortcutsRows(.layers, old: old, new: new)
                .isEmpty
        )
        #expect(
            SettingsValueReadout.shortcutsRows(
                .shortcutBase,
                old: old,
                new: new
            ).count == 1
        )
        new.layers[0].bindings[0].combo = "f13"
        #expect(
            SettingsValueReadout.shortcutsRows(.layers, old: old, new: new)
                .count == 1
        )
    }

    @Test("rows left on ⌃⌥ carry their reasons")
    func leftRowsAreReasoned() throws {
        let floating = try #require(
            seed.first { $0.lua == "KiwiDesk.toggle_floating()" }
        )
        var mine = try #require(
            seed.first { $0.lua == "KiwiDesk.toggle_sticky()" }
        )
        mine.combo = "control+option+shift+y"
        let held = row("control+option+p", "KiwiDesk.toggle_display_sticky()")
        let holder = row("p", "hs.x()")
        let model = model([floating, mine, held, holder])
        #expect(model.rowsLeftOnStandard.isEmpty)
        model.config.shortcutBase = .hyper
        let reasons = model.rowsLeftOnStandard.map(\.reason)
        #expect(reasons.count == 3)
        #expect(reasons[0] == .predates)
        #expect(reasons[1] == .ownChoice)
        guard case .taken = reasons[2] else {
            Issue.record("expected the held row's reason")
            return
        }
    }

    @Test("a switch back restores the seed")
    func backRestores() {
        let model = model(seed)
        model.setShortcutBase(.hyper)
        model.setShortcutBase(.standard)
        #expect(model.config.layers[0].bindings == seed)
        #expect(model.config.shortcutBase == .standard)
    }

    /// The surfacing branches only a scan sees (gui.md): the row in
    /// the card, its staging, its greys and the list under it.
    @Test("the switch, its greys and the list are wired")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        func source(_ path: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(path),
                    encoding: .utf8
                )
            )
        }
        let card = try source("Components/Keybindings/ModifierKeysCard.swift")
        #expect(
            card.contains(
                "ShortcutBaseRow(model: model, reason: offerReason)"
            )
        )
        #expect(card.contains("usesHyper: model.draftUsesHyper"))
        #expect(
            card.contains("editingStoredProfile: model.editingStoredProfile")
        )
        let row = try source("Components/Keybindings/ShortcutBaseRow.swift")
        #expect(row.contains("set: { model.setShortcutBase($0) }"))
        #expect(row.contains("picker.modifier(GreyOut(active: greyed"))
        #expect(row.contains("if !left.isEmpty { leftList }"))
        #expect(row.contains("model.rowsLeftOnStandard"))
        #expect(row.contains("return ShortcutBaseWords.storedPage"))
        #expect(
            row.contains(
                "? ShortcutBaseWords.keyOff : ShortcutBaseWords.noKey"
            )
        )
        #expect(row.contains("spokenValue: ShortcutBaseWords.spoken("))
    }
}
