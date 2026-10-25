import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// An open KiwiHub draws the live settings, not the ones it opened
/// with (#2604): a CLI colour or glass change reaches the shown
/// panel's model, the view reads its glass from that model, and the
/// app hands the one settings hook to KiwiHub through its fan-out.
/// The panel is built for real; only the close test orders it in.
@Suite("KiwiHub live settings (#2604)")
@MainActor
struct JumpPanelLiveSettingsTests {
    private func shown() -> (JumpPanelController, KiwiCore) {
        let core = makeTestCore()
        // Off the default, so the read at open is seen.
        core.tiler.settings.kiwishelf.fillColor = "#102030B3"
        let controller = JumpPanelController(core: core)
        controller.reduceMotion = { true }
        controller.handBack.isAppActive = { true }
        controller.handBack.nextTurn = { _ in }
        core.onSettingsChange = { [weak controller] in
            controller?.settingsChanged($0)
        }
        controller.show(.view)
        return (controller, core)
    }

    @Test("a CLI Fill change reaches the open panel")
    func fillReachesThePanel() throws {
        let (controller, core) = shown()
        let model = try #require(controller.currentModel)
        #expect(model.settings == core.tiler.settings)
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

    @Test("a closed panel's model keeps its settings")
    func closedPanelIsLeftAlone() throws {
        let (controller, core) = shown()
        let model = try #require(controller.currentModel)
        let opened = model.settings
        // `close` refuses a panel that never came up.
        let panel = try #require(controller.panel)
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        try #require(panel.isVisible)
        controller.close()
        #expect(!controller.isOpen)
        core.tiler.settings.shortcutPanelLiquidGlass.toggle()
        #expect(model.settings == opened)
    }

    /// The hook is one slot, so a second assignment would unhook
    /// KiwiHub with every behavioural test above still green: the
    /// GUI assigns it once, in the app's fan-out, which hands it to
    /// the panel, and Core only in the accessor's setter.
    @Test("the app wires the hook once, through its fan-out")
    func hookIsWiredOnce() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let gui = root.appendingPathComponent("Sources/KiwiDesk")
        let assign = try NSRegularExpression(
            pattern: #"\.onSettingsChange\s*="#
        )
        var sites: [String] = []
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty)
            for file in files {
                let source = try SourceScan.strippedSource(at: file)
                let range = NSRange(source.startIndex..., in: source)
                let count = assign.numberOfMatches(
                    in: source,
                    range: range
                )
                sites += Array(repeating: file.lastPathComponent, count: count)
            }
        }
        #expect(
            sites == [
                "KiwiCore+Accessors.swift",
                "AppDelegate+SettingsReaders.swift",
            ]
        )
        let fanOut = try SourceScan.strippedSource(
            at: gui.appendingPathComponent(
                "AppDelegate+SettingsReaders.swift"
            )
        )
        let wiring = try NSRegularExpression(
            pattern: #"onSettingsChange\s*=\s*\{[\s\S]{0,80}?"#
                + #"settingsReadersChanged\(\s*\$0\s*\)"#
                + #"[\s\S]*jumpPanel\?\.settingsChanged\(\s*settings\s*\)"#
        )
        let range = NSRange(fanOut.startIndex..., in: fanOut)
        #expect(
            wiring.numberOfMatches(in: fanOut, range: range) == 1,
            "the fan-out no longer hands the settings to KiwiHub"
        )
        let delegate = try SourceScan.strippedSource(
            at: gui.appendingPathComponent("AppDelegate.swift")
        )
        #expect(delegate.contains("wireSettingsReaders()"))
    }
}
