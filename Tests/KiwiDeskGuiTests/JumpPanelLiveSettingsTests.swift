import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// An open KiwiHub draws the live settings, not the ones it opened
/// with (#2604): a CLI colour or glass change reaches the shown
/// panel's model, and the view reads its glass from that model.
/// The panel is built for real but never ordered in.
@Suite("KiwiHub live settings (#2604)")
@MainActor
struct JumpPanelLiveSettingsTests {
    private func shown() -> (JumpPanelController, KiwiCore) {
        let core = makeTestCore()
        let controller = JumpPanelController(core: core)
        controller.reduceMotion = { true }
        controller.handBack.isAppActive = { true }
        controller.handBack.nextTurn = { _ in }
        controller.show(.view)
        return (controller, core)
    }

    @Test("a CLI Fill change reaches the open panel")
    func fillReachesThePanel() throws {
        let (controller, core) = shown()
        let model = try #require(controller.currentModel)
        let hex = "#3A1F5CB3"
        #expect(model.settings.kiwishelf.fillColor != hex)
        _ = core.execute("kiwishelf.set_fill_color", args: [.string(hex)])
        #expect(core.tiler.settings.kiwishelf.fillColor == hex)
        #expect(model.settings == core.tiler.settings)
    }

    @Test("the open panel's glass follows the live leaf")
    func glassFollowsTheLeaf() throws {
        let (controller, core) = shown()
        let model = try #require(controller.currentModel)
        let view = JumpPanelView(
            model: model,
            presence: PanelPresence(),
            width: JumpPanelView.width
        )
        let opened = view.panelGlass.enabled
        core.tiler.settings.shortcutPanelLiquidGlass = !opened
        #expect(view.panelGlass.enabled == !opened)
        #expect(view.panelGlass == PanelGlass(settings: core.tiler.settings))
    }
}
