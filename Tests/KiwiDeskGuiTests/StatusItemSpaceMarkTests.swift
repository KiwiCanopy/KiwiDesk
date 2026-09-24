import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A status item carrying a REAL button so the drawing is
/// observable; never `NSStatusBar.system`, which
/// `StatusItemSeamGuardTests` seals.
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = NSStatusBarButton()
    var menu: NSMenu?
}

@MainActor
private final class FakeUpdater: AppUpdating {
    var installsAutomatically = false
    var whatsNew: WhatsNewCoordinator? { nil }
    let updates = UpdateStateStore()
    var canCheckForUpdates = true
    var updatePending = false { didSet { onUpdatePendingChanged() } }
    var onUpdatePendingChanged: () -> Void = {}
    func checkForUpdates() {}
}

/// The menu bar's layer and Space mark (#1413), the GUI half:
/// with screens the item draws ONE image — a template unless an
/// emoji is in it — named for VoiceOver with the layer and every
/// screen's Space in desk order; without screens (the bar on) it
/// draws the layer's icon alone, or the brand glyph for an
/// icon-less layer, as before; the broken and starting states
/// outrank both, and the #1013 mark rides on top; the pixels are
/// `StatusItemSpaceMarkDrawingTests`'. `.serialized`:
/// names are matched in English through the process-wide
/// `LocalizationManager`. `@MainActor` for the AppKit button and
/// the image draws; the wiring needle spends one file read on it.
@Suite("Status item Space mark (#1413)", .serialized)
@MainActor
struct StatusItemSpaceMarkTests {
    private func display(_ id: UInt32, x: CGFloat) -> Display {
        Display(
            id: DisplayID(id),
            name: "\(id)",
            frame: CGRect(x: x, y: 0, width: 1000, height: 600)
        )
    }

    private func screen(
        _ id: UInt32,
        x: CGFloat,
        space: String,
        glyph: StatusSpaceMark.Glyph? = nil
    ) -> StatusSpaceMark.Screen {
        StatusSpaceMark.Screen(
            display: display(id, x: x),
            space: SpaceID(space),
            glyph: glyph ?? .text(space, tinted: true)
        )
    }

    private func layer(
        _ name: String,
        glyph: StatusSpaceMark.Glyph,
        hasIcon: Bool = true
    ) -> StatusSpaceMark.Layer {
        .init(name: name, glyph: glyph, hasIcon: hasIcon)
    }

    private func controller() -> (StatusItemController, FakeUpdater) {
        let controller = StatusItemController(item: FakeStatusItem())
        let updater = FakeUpdater()
        controller.updater = updater
        return (controller, updater)
    }

    @Test("the mark is drawn as one template image and named")
    func drawnAndNamed() throws {
        LocalizationManager.shared.select("en")
        let (controller, _) = controller()
        let button = try #require(controller.anchorButton)
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: nil,
                screens: [screen(1, x: 0, space: "mail")]
            )
        )
        let image = try #require(button.image)
        #expect(image is StatusItemController.SpaceMarkImage)
        #expect(image.isTemplate)
        #expect(image.size.width > 0)
        #expect(button.title.isEmpty)
        #expect(button.accessibilityLabel() == "KiwiDesk (Space mail)")
        #expect(button.toolTip == "KiwiDesk (Space mail)")
        controller.setSpaceMark(nil)
        #expect(
            !(try #require(button.image)
                is StatusItemController.SpaceMarkImage)
        )
        #expect(button.accessibilityLabel() == "KiwiDesk")
    }

    /// The bar-on shape is the old one: the layer's icon alone,
    /// named as the app; an icon-less layer keeps the brand glyph.
    @Test("without screens the layer icon draws alone, or the brand")
    func layerAloneWithoutScreens() throws {
        LocalizationManager.shared.select("en")
        let (controller, _) = controller()
        let button = try #require(controller.anchorButton)
        // A screened mark first, so the label the layer path
        // owes is asserted against a stale composite name rather
        // than the init render's (guard-prover, 2026-09-20).
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: nil,
                screens: [screen(1, x: 0, space: "mail")]
            )
        )
        #expect(button.accessibilityLabel() == "KiwiDesk (Space mail)")
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: layer("resize", glyph: .symbol("star.fill")),
                screens: []
            )
        )
        let icon = try #require(button.image)
        #expect(!(icon is StatusItemController.SpaceMarkImage))
        #expect(icon.accessibilityDescription == "star.fill")
        #expect(button.accessibilityLabel() == "KiwiDesk")
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: layer("svc", glyph: .text("⚙", tinted: true)),
                screens: []
            )
        )
        #expect(button.image == nil)
        #expect(button.title == "⚙")
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: layer(
                    "svc",
                    glyph: .text("SV", tinted: true),
                    hasIcon: false
                ),
                screens: []
            )
        )
        #expect(button.title.isEmpty)
        #expect(
            try #require(button.image).accessibilityDescription
                == "KiwiDesk"
        )
    }

    @Test("the layer leads and the screens follow in desk order")
    func layerLeadsScreensInDeskOrder() {
        LocalizationManager.shared.select("en")
        let resize = layer("resize", glyph: .symbol("arrow.left.and.right"))
        let mark = StatusSpaceMark(
            layer: resize,
            screens: [
                screen(8, x: 1000, space: "side"),
                screen(7, x: 0, space: "main", glyph: .symbol("envelope")),
            ]
        )
        #expect(
            StatusItemController.spaceMarkGlyphs(mark) == [
                .symbol("arrow.left.and.right"),
                .symbol("envelope"),
                .text("side", tinted: true),
            ]
        )
        #expect(
            StatusItemController.spaceMarkName(mark)
                == "KiwiDesk (“resize” layer, Spaces main and side)"
        )
        #expect(
            StatusItemController.spaceMarkName(
                StatusSpaceMark(
                    layer: resize,
                    screens: [screen(7, x: 0, space: "main")]
                )
            ) == "KiwiDesk (“resize” layer, Space main)"
        )
        #expect(
            StatusItemController.spaceMarkName(
                StatusSpaceMark(
                    layer: nil,
                    screens: [
                        screen(8, x: 1000, space: "side"),
                        screen(7, x: 0, space: "main"),
                    ]
                )
            ) == "KiwiDesk (Spaces main and side)"
        )
    }

    @Test("the update mark rides the composite and lifts off again")
    func precedence() throws {
        LocalizationManager.shared.select("en")
        let (controller, updater) = controller()
        let button = try #require(controller.anchorButton)
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: layer("resize", glyph: .text("RE", tinted: true)),
                screens: [screen(1, x: 0, space: "main")]
            )
        )
        #expect(button.image is StatusItemController.SpaceMarkImage)
        updater.updatePending = true
        #expect(button.image is StatusItemController.UpdateMarkImage)
        #expect(
            button.accessibilityLabel()?.contains("update") == true
        )
        updater.updatePending = false
        #expect(button.image is StatusItemController.SpaceMarkImage)
        #expect(
            button.accessibilityLabel()
                == "KiwiDesk (“resize” layer, Space main)"
        )
    }

    /// The wiring no behaviour test can red on: `AppDelegate`
    /// cannot be instantiated here, so the assignment that hands
    /// Core's change to the controller is pinned by needle,
    /// whole — the seam AND its consumer in one statement, since
    /// a closure wired to nothing matches a looser one.
    @Test("the delegate wires Core's change to the controller")
    func delegateWiresTheSeam() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/AppDelegate.swift")
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        ).replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(
            source.contains(
                "core.onStatusSpaceMarkChange={[weakself]markin"
                    + "self?.statusItem?.setSpaceMark(mark)}"
            )
        )
    }

    @Test("the broken and starting states outrank the mark")
    func brokenStatesOutrankTheMark() throws {
        LocalizationManager.shared.select("en")
        let (controller, _) = controller()
        let button = try #require(controller.anchorButton)
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: nil,
                screens: [screen(1, x: 0, space: "main")]
            )
        )
        controller.setWarning(true)
        #expect(
            !(try #require(button.image)
                is StatusItemController.SpaceMarkImage)
        )
        #expect(
            button.accessibilityLabel()?.contains("permission") == true
        )
        controller.setWarning(false)
        controller.setBootPhase(.scanning(scanned: 1, total: 2))
        #expect(
            !(try #require(button.image)
                is StatusItemController.SpaceMarkImage)
        )
        controller.setBootPhase(.ready)
        controller.setConfigError(true)
        #expect(
            !(try #require(button.image)
                is StatusItemController.SpaceMarkImage)
        )
        controller.setConfigError(false)
        #expect(button.image is StatusItemController.SpaceMarkImage)
    }
}
