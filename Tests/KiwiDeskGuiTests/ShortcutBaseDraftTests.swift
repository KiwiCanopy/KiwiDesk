import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shortcut base rides the draft beside the rows it moves
/// (#2460): a dropped rule half drops it too, Restore Defaults writes
/// the seed on it, and a top-up row adopted into a staged draft
/// takes it.
@Suite("Shortcut base: the base stays with its rows in the draft")
@MainActor
struct ShortcutBaseDraftTests {
    private func movedModel() throws -> SettingsModel {
        let core = makeTestCore()
        core.setAppWide(persisting: false) { $0.hyperKey = .capsLock }
        let model = makeTestModel(core: core)
        var config = GuiConfig()
        config.spaces = [SpaceID(1)]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: DefaultKeybindings.appChromeRows()
                    + [1, 2].compactMap {
                        DefaultKeybindings.desktopRow($0, base: .standard)
                    }
            )
        ]
        model.config = config
        model.cleanConfig = config
        model.setShortcutBase(.hyper)
        #expect(model.config.shortcutBase == .hyper)
        return model
    }

    private func desktopCombos(_ model: SettingsModel) -> [String] {
        model.config.layers[0].bindings
            .filter { DefaultKeybindings.isDesktopRow($0) }
            .map(\.combo)
    }

    @Test("dropping the rule half drops the base with the rows")
    func dropRuleHalfDropsTheBase() throws {
        let model = try movedModel()
        model.dropRuleHalf()
        #expect(model.config.shortcutBase == .standard)
        #expect(desktopCombos(model).allSatisfy { !$0.hasPrefix("hyper") })
    }

    @Test("Restore Defaults writes the Desktop rows on the draft's base")
    func restoreDefaultsTakesTheBase() throws {
        let model = try movedModel()
        model.bindableDesktops = [1, 2]
        model.resetShortcutsToDefaults()
        #expect(desktopCombos(model) == ["hyper+option+1", "hyper+option+2"])
    }

    @Test("a top-up row adopted into a staged draft takes its base")
    func topUpRowTakesTheStagedBase() throws {
        let model = try movedModel()
        let row = try #require(
            DefaultKeybindings.desktopRow(3, base: .standard)
        )
        model.adoptShortcutAdd([row])
        #expect(desktopCombos(model).last == "hyper+option+3")
    }
}
