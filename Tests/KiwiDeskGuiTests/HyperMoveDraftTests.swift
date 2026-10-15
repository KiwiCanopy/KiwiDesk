import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktop base rides the draft beside the rows it moves (#1870):
/// a dropped rule half drops it too, Restore Defaults writes Desktop
/// rows on it, and a top-up row adopted into a staged draft takes it.
@Suite("Hyper move: the base stays with its rows in the draft")
@MainActor
struct HyperMoveDraftTests {
    private func movedModel() throws -> SettingsModel {
        let core = makeTestCore()
        core.setAppWide(persisting: false) { $0.hyperKey = .capsLock }
        let model = makeTestModel(core: core)
        var config = GuiConfig()
        config.spaces = [SpaceID(1)]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [1, 2].compactMap {
                    DefaultKeybindings.desktopRow($0)
                }
            )
        ]
        model.config = config
        model.cleanConfig = config
        let request = try #require(model.hyperMoveRequest())
        model.applyHyperMove(request, items: [], desktop: true)
        #expect(model.config.desktopShortcutBase == .hyper)
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
        #expect(model.config.desktopShortcutBase == .standard)
        #expect(desktopCombos(model).allSatisfy { !$0.hasPrefix("hyper") })
    }

    @Test("Restore Defaults writes the Desktop rows on the draft's base")
    func restoreDefaultsTakesTheBase() throws {
        let model = try movedModel()
        model.bindableDesktops = [1, 2]
        model.resetShortcutsToDefaults()
        #expect(desktopCombos(model) == ["hyper+1", "hyper+2"])
    }

    @Test("a top-up row adopted into a staged draft takes its base")
    func topUpRowTakesTheStagedBase() throws {
        let model = try movedModel()
        let row = try #require(DefaultKeybindings.desktopRow(3))
        model.adoptShortcutAdd([row])
        #expect(desktopCombos(model).last == "hyper+3")
    }
}
