import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Simple's sections (#2737): the Screen menu's one placement door,
/// the save pill's jump, and Simple drawing Advanced's own parts.
/// Main-actor spend: model construction and one source walk of a
/// single directory.
@MainActor
@Suite("Simple sections")
struct SimpleSectionsTests {
    private func onSimple() -> SettingsModel {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(.simple, to: defaults)
        return makeTestModel(defaults: defaults)
    }

    @Test("each placement clears the other one")
    func placementRoundTrips() {
        let model = onSimple()
        let space = SpaceID("1")
        model.place(space, .screen("fp-a"))
        #expect(model.config.spacePins[space] == "fp-a")
        #expect(model.screenChoice(of: space) == .screen("fp-a"))
        model.place(space, .followsMain)
        #expect(model.config.spacePins[space] == nil)
        #expect(model.config.mainSpaces.contains(space))
        #expect(model.screenChoice(of: space) == .followsMain)
        model.place(space, .screen("fp-b"))
        #expect(!model.config.mainSpaces.contains(space))
        model.place(space, .auto)
        #expect(model.config.spacePins[space] == nil)
        #expect(!model.config.mainSpaces.contains(space))
        #expect(model.screenChoice(of: space) == .auto)
    }

    /// Screens' chips, drops and orphan clear and Simple's menu
    /// share one meaning of a placement, so no Settings file but the
    /// door writes a pin or the main-screen set.
    @Test("a Space's placement has one writer")
    func placementHasOneDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        let door = "SettingsModel+SpaceScreenChoice.swift"
        // An assignment, not a comparison: `]=` not followed by `=`.
        let write = try NSRegularExpression(
            pattern: #"spacePins\[[^\]]*\]=(?!=)|"#
                + #"mainSpaces\.(insert|remove)\("#
        )
        var writers: [String] = []
        for file in files where file.lastPathComponent != door {
            let text = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
            let range = NSRange(text.startIndex..., in: text)
            if write.firstMatch(in: text, range: range) != nil {
                writers.append(file.lastPathComponent)
            }
        }
        #expect(writers.isEmpty, "\(writers)")
    }

    private func row(_ key: SettingKey) -> SettingsDiffRow {
        SettingsDiffRow(id: "row", key: key, label: "Row")
    }

    /// Ruling 12: a row Simple draws stays; any other leaves.
    @Test("a pill row leaves Simple only for a control it lacks")
    func pillRowJump() {
        let model = onSimple()
        model.jump(to: row(.spaces(.spaceModes)))
        #expect(model.nav.pendingReveal == nil)
        model.jump(to: row(.gaps(.outerTop)))
        #expect(model.nav.pendingReveal != nil)
        // On Advanced every row lands on its page.
        model.nav.pendingReveal = nil
        model.pickRoot(.advanced)
        model.jump(to: row(.spaces(.spaceModes)))
        #expect(model.nav.pendingReveal?.destination == .spaces)
    }

    @Test("Simple's hints place their links")
    func hintsPlaceTheirLinks() {
        LocalizationManager.shared.select("en")
        for prose in [SimpleLookCard.hintProse, SimpleSpacesCard.hintProse] {
            #expect(prose.contains(CrossReferenceRow.linkSlot))
        }
    }

    @Test("Simple's coverage reads the row, not its key alone")
    func coverage() {
        let model = onSimple()
        #expect(SimpleCoverage.draws(row(.spaces(.spaceModes)), in: model))
        #expect(!SimpleCoverage.draws(row(.spaces(.fallbackSpace)), in: model))
        #expect(!SimpleCoverage.draws(row(.gaps(.outerTop)), in: model))
        // A pin is Simple's only where it draws the Screen menu.
        for screenMenu in [true, false] {
            #expect(
                SimpleCoverage.draws(
                    row(.screens(.spacePins)),
                    screenMenu: screenMenu,
                    binding: { _ in false }
                ) == screenMenu
            )
        }
        // A binding row: KiwiHub's keys and app rows, default
        // layer alone.
        let hub = KeybindingCatalog.jumpToWindow.lua
        var binding = row(.shortcuts(.layers))
        binding.revert = .binding(layer: KeyLayer.defaultName, lua: hub)
        #expect(SimpleCoverage.draws(binding, in: model))
        binding.revert = .binding(layer: "Gaming", lua: hub)
        #expect(!SimpleCoverage.draws(binding, in: model))
        binding.revert = .binding(
            layer: KeyLayer.defaultName,
            lua: KeybindingCatalog.toggleSpaceBar.lua
        )
        #expect(!SimpleCoverage.draws(binding, in: model))
    }

    /// An app key recorded on Simple yields a row that stays.
    @Test("an app key's pill row stays on Simple")
    func appRowStays() throws {
        let model = onSimple()
        let found = model.config.layers.firstIndex { $0.isDefault }
        let index = try #require(found)
        model.config.layers[index].bindings.append(
            KeyBinding(
                combo: "ctrl+alt+s",
                lua: KeybindingCatalog.appCommand(
                    "com.apple.Safari",
                    action: .openOrFocus
                ),
                kind: .application
            )
        )
        let rows = SettingsDiffRowSource.rows(for: model)
        let binding = rows.first {
            if case .binding = $0.revert { return true }
            return false
        }
        let added = try #require(binding)
        #expect(SimpleCoverage.draws(added, in: model))
        model.jump(to: added)
        #expect(model.nav.pendingReveal == nil)
        // A key removed on Simple: its row reads the saved config.
        model.cleanConfig = model.config
        model.config.layers[index].bindings.removeAll {
            $0.kind == .application
        }
        let removed = SettingsDiffRowSource.rows(for: model).first {
            if case .binding = $0.revert { return true }
            return false
        }
        let removedRow = try #require(removed)
        #expect(SimpleCoverage.draws(removedRow, in: model))
    }

    /// Simple owns layout only: a tile, a recorder or a layout
    /// menu is drawn by the component Advanced draws it with, so
    /// none is built from parts under Simple's directory.
    @Test("Simple builds no control of its own")
    func noLookAlikes() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Simple"
            )
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        let parts = [
            "PaletteTile(", "LookPlate(", "KeyRecorderField(",
            "LayoutMode.allCases", "OverrideCountBadge(",
            "SpacePinBadge.resolve(", "monitor_chip.automatic",
            "monitor_card.follows_main", "model.displays.map",
        ]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            for part in parts {
                #expect(
                    !text.contains(part),
                    "\(file.lastPathComponent) builds \(part)"
                )
            }
        }
    }
}
