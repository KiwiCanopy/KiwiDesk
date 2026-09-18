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
    var canCheckForUpdates = true
    var updatePending = false { didSet { onUpdatePendingChanged() } }
    var onUpdatePendingChanged: () -> Void = {}
    func checkForUpdates() {}
}

/// The menu bar's Space Bar stand-in (#1413), the GUI half: the
/// item draws the mark as ONE image — a template unless an emoji
/// is in it — names it for VoiceOver with the layer and every
/// screen's Space in desk order, lets the broken and starting
/// states outrank it and carries the #1013 mark on top like the
/// brand icon does. `.serialized`: names are matched in English
/// through the process-wide `LocalizationManager`.
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
        glyph: SpaceMark? = nil
    ) -> StatusSpaceMark.Screen {
        StatusSpaceMark.Screen(
            display: display(id, x: x),
            space: SpaceID(space),
            glyph: glyph ?? .text(space)
        )
    }

    private func controller() -> (StatusItemController, FakeUpdater) {
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(item: FakeStatusItem())
        let updater = FakeUpdater()
        controller.updater = updater
        return (controller, updater)
    }

    @Test("the mark is drawn as one template image and named")
    func drawnAndNamed() throws {
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

    @Test("an emoji keeps its colour: the image is no template")
    func emojiIsNoTemplate() throws {
        let (controller, _) = controller()
        let button = try #require(controller.anchorButton)
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: nil,
                screens: [screen(1, x: 0, space: "web", glyph: .text("🌐"))]
            )
        )
        #expect(try #require(button.image).isTemplate == false)
    }

    @Test("the layer leads and the screens follow in desk order")
    func layerLeadsScreensInDeskOrder() {
        LocalizationManager.shared.select("en")
        let mark = StatusSpaceMark(
            layer: .init(
                name: "resize",
                glyph: .symbol("arrow.left.and.right")
            ),
            screens: [
                screen(8, x: 1000, space: "side"),
                screen(7, x: 0, space: "main", glyph: .symbol("envelope")),
            ]
        )
        #expect(
            StatusItemController.spaceMarkGlyphs(mark) == [
                .symbol("arrow.left.and.right"),
                .symbol("envelope"),
                .text("side"),
            ]
        )
        #expect(
            StatusItemController.spaceMarkName(mark)
                == "KiwiDesk (resize layer, Spaces main and side)"
        )
        #expect(
            StatusItemController.spaceMarkName(
                StatusSpaceMark(
                    layer: mark.layer,
                    screens: [screen(7, x: 0, space: "main")]
                )
            ) == "KiwiDesk (resize layer, Space main)"
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

    /// A one-glyph mark and a two-glyph mark differ by a divider
    /// and the second glyph: the composite grows with its runs.
    @Test("a second glyph widens the image")
    func widthGrowsWithRuns() {
        let one = StatusItemController.spaceMarkImage(
            StatusSpaceMark(
                layer: nil,
                screens: [screen(1, x: 0, space: "main")]
            )
        )
        let two = StatusItemController.spaceMarkImage(
            StatusSpaceMark(
                layer: .init(name: "resize", glyph: .text("RE")),
                screens: [screen(1, x: 0, space: "main")]
            )
        )
        #expect(two.size.width > one.size.width + 10)
        #expect(one.size.height == two.size.height)
    }

    @Test("the mark outranks the layer icon and the update mark rides it")
    func precedence() throws {
        let (controller, updater) = controller()
        let button = try #require(controller.anchorButton)
        controller.setModeIcon("star.fill")
        controller.setSpaceMark(
            StatusSpaceMark(
                layer: .init(name: "resize", glyph: .text("RE")),
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
                == "KiwiDesk (resize layer, Space main)"
        )
    }

    /// The wiring no behaviour test can red on: `AppDelegate`
    /// cannot be instantiated here, so the assignment that hands
    /// the manager's change to the controller is pinned by
    /// needle, whole — the seam AND its consumer in one
    /// statement, since a closure wired to nothing matches a
    /// looser one.
    @Test("the delegate wires the manager's change to the controller")
    func delegateWiresTheSeam() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/AppDelegate.swift")
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        ).replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(
            source.contains(
                "core.spaceBars.onStatusMarkChange={[weakself]markin"
                    + "self?.statusItem?.setSpaceMark(mark)}"
            )
        )
    }

    @Test("the broken and starting states outrank the mark")
    func brokenStatesOutrankTheMark() throws {
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
