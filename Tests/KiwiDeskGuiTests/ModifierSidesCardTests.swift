import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Modifier keys card's sides switch (#2601): its live caption,
/// the card's hold-open, the side-collapse tier and the reads the
/// recorder and the card take from the model.
@Suite("Modifier keys card: the sides switch (#2601)")
@MainActor
struct ModifierSidesCardTests {
    private func binding(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation, label: lua)
    }

    @Test("a caption shows only a live fact")
    func captionStates() {
        LocalizationManager.shared.select("en")
        typealias Row = ModifierSidesRow
        #expect(Row.captionText(on: false, status: .off, sided: 0) == nil)
        #expect(Row.captionText(on: true, status: .running, sided: 2) == nil)
        #expect(Row.captionText(on: true, status: .off, sided: 0) == nil)
        #expect(
            Row.captionText(on: false, status: .off, sided: 2)
                == ModifierSidesWords.waiting(2)
        )
        #expect(ModifierSidesWords.waiting(2).contains("2"))
        #expect(
            Row.captionText(on: true, status: .refused, sided: 1)
                == ModifierSidesWords.refused
        )
    }

    @Test("the card's order list holds every row placed on it")
    func orderListIsTheContainer() {
        let placed = SettingKey.allCases.filter {
            $0.placement.container == .modifierKeys
        }
        #expect(placed.contains(.shortcuts(.modifierSides)))
        #expect(Set(ShortcutsRowOrder.modifierKeysList) == Set(placed))
    }

    @Test("the card holds open on the sides the model reads")
    func cardWiresTheOffer() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "ModifierKeysCard.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(
            source.contains(
                "model.appWide.modifierSides || model.sidedShortcutCount > 0"
            )
        )
        // The hold-open takes it.
        #expect(
            source.components(separatedBy: "keepsSides: keepsSides").count
                == 2
        )
        #expect(source.contains("ModifierSidesRow(model: model)"))
        let row = SourceScan.stripComments(
            try String(
                contentsOf: file.deletingLastPathComponent()
                    .appendingPathComponent("ModifierSidesRow.swift"),
                encoding: .utf8
            )
        )
        #expect(row.contains(".inertReason(for: .shortcuts(.modifierSides))"))
        #expect(row.contains("disabled: reason == .appWideLuaOwned"))
    }

    @Test("the model counts sided rows and hands the recorder its sides")
    func modelReads() {
        let model = makeTestModel()
        #expect(model.recorderSides == nil)
        let before = model.sidedShortcutCount
        model.config.layers[0].bindings.append(
            binding("rcmd+h", "KiwiDesk.focus(\"left\")")
        )
        #expect(model.sidedShortcutCount == before + 1)
        model.setAppWide {
            $0.modifierSides = true
            $0.hyperKey = .rightCommand
        }
        // Keyed on the key being set, whatever its remap's status:
        // the test core's remap never ran.
        #expect(model.hyperStatus != .on)
        #expect(
            model.recorderSides == RecorderSides(hyperKey: .rightCommand)
        )
    }

    @Test("a side collapse is its own tier, pointing at the switch")
    func sideCollapseTier() {
        LocalizationManager.shared.select("en")
        let left = binding("lcmd+h", "KiwiDesk.focus(\"left\")")
        let right = binding("rcmd+h", "KiwiDesk.focus(\"right\")")
        let severity = ConflictText.severity(
            for: left,
            in: [left, right],
            disabled: [],
            sides: false
        )
        #expect(severity == .sideCollapse(right))
        #expect(severity?.isDead == false)
        let sentence = ConflictText.sentence(
            for: .sideCollapse(right),
            config: GuiConfig()
        )
        #expect(sentence.contains(ModifierSidesWords.title))
        let on = ConflictText.severity(
            for: left,
            in: [left, right],
            disabled: [],
            sides: true
        )
        // On, the two are two shortcuts; ⌘H may still meet Hide.
        #expect(on != .sideCollapse(right))
        #expect(on != .duplicate(right))
    }

    @Test("the conflict popover's Go to lands on the switch")
    func goToTheSwitch() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "Recorder/KeyRecorderField+Conflict.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(source.contains("if case .sideCollapse = reading?.severity"))
        #expect(
            source.contains(
                "coordinator.scrollTarget =\n"
                    + "                    SettingsCatalog.shortcuts"
                    + ".modifierKeys.children\n"
                    + "                    .modifierSides.id"
            )
        )
        #expect(source.contains("sideSwitchLink\n"))
    }

    @Test("a menu never draws a sided chord unsided")
    func menuSkipsSidedChords() throws {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let sided = try #require(KeyCombo.parse("rcmd+k"))
        StatusItemController.applyMenuEquivalent(sided, to: item)
        #expect(item.keyEquivalent.isEmpty)
        let plain = try #require(KeyCombo.parse("cmd+k"))
        StatusItemController.applyMenuEquivalent(plain, to: item)
        #expect(!item.keyEquivalent.isEmpty)
    }
}
