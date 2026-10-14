import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Fake menu-bar slot so this suite never registers a real
/// system status item (#565-class seam).
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = nil
    var menu: NSMenu?
}

/// The quick menu's KiwiVision row (#2103): a checkmark mirroring
/// the mode, its live chord in the native column, greyed while
/// tiling has not started, and its action reaching Core once —
/// AppKit's duplicate keyDown for a chord Carbon answered is
/// dropped. `.serialized`: titles are matched in English.
@Suite("Quick menu KiwiVision row", .serialized)
@MainActor
struct QuickMenuKiwiVisionRowTests {
    private func row(
        on: Bool,
        combo: KeyCombo? = nil,
        idle: Bool = false,
        toggled: @escaping () -> Void = {}
    ) -> (StatusItemController, NSMenuItem?) {
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(item: FakeStatusItem())
        controller.kiwiVisionProvider = { on }
        controller.kiwiVisionComboProvider = { combo }
        controller.onToggleKiwiVision = toggled
        controller.setTilingIdle(idle)
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        return (controller, menu.items.first { $0.title == "KiwiVision" })
    }

    @Test("the row is listed and mirrors the mode")
    func rowMirrorsTheMode() {
        #expect(row(on: true).1?.state == .on)
        #expect(row(on: false).1?.state == .off)
    }

    @Test("the row shows the live chord")
    func rowShowsTheChord() {
        let combo = KeyCombo.parse("control+option+v")
        let item = row(on: false, combo: combo).1
        #expect(item?.keyEquivalent == "v")
        #expect(
            item?.keyEquivalentModifierMask == [.control, .option]
        )
    }

    @Test("the row is greyed until tiling starts")
    func rowGreysWhileIdle() {
        #expect(row(on: false, idle: true).1?.isEnabled == false)
        #expect(row(on: false).1?.isEnabled == true)
    }

    @Test("a click toggles once; a keyDown duplicate does not")
    func clickToggles() {
        var count = 0
        let (controller, item) = row(on: false) { count += 1 }
        controller.menuActionIsKeyDown = { false }
        controller.toggleKiwiVision()
        #expect(count == 1)
        controller.menuActionIsKeyDown = { true }
        controller.toggleKiwiVision()
        #expect(count == 1)
        #expect(
            item?.action == #selector(StatusItemController.toggleKiwiVision)
        )
    }

    /// The wiring lives in `AppDelegate+KiwiVision`, which no test
    /// constructs: the providers read Core, the action toggles it
    /// and VoiceOver hears Core's change.
    @Test("the app delegate wires the row and the announcement")
    func delegateWiresTheRow() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let text = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate+KiwiVision.swift"
            )
        ).filter { !$0.isWhitespace }
        for needle in [
            "self?.core.kiwiVisionIsOn",
            "lua:KeybindingCatalog.toggleKiwiVision.lua",
            "self?.core.toggleKiwiVision()",
            "core.vision.onChange={[weakself]onin",
            "core.onAppWideChange={[weakself]in",
            "notification:.announcementRequested",
        ] {
            #expect(text.contains(needle), "missing \(needle)")
        }
        let delegate = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate.swift"
            )
        )
        #expect(delegate.contains("wireKiwiVision()"))
    }
}
