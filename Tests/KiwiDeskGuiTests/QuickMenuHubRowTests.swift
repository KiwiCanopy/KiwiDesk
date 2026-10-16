import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Fake menu-bar slot so this suite never registers a real
/// system status item (#565-class seam); the Gui convention is
/// a per-file fake, and `StatusItemSeamGuardTests` pins that
/// every test construction injects one.
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = nil
    var menu: NSMenu?
}

/// The quick menu's chord rows (#2309 ruling 8): one "Open
/// KiwiHub…" row opening the View side in place of the Layout,
/// Switch Profile, KiwiVision and View Shortcuts rows, and the
/// Settings row, each showing its live chord. `.serialized`
/// because `LocalizationManager` is a process-wide singleton
/// (titles are matched in English).
@Suite("Quick menu KiwiHub and Settings rows", .serialized)
@MainActor
struct QuickMenuHubRowTests {
    private func reset() {
        LocalizationManager.shared.select("en")
    }

    private func controller() -> StatusItemController {
        StatusItemController(item: FakeStatusItem())
    }

    private func titles(_ controller: StatusItemController) -> [String] {
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        return menu.items.map(\.title)
    }

    /// Ruling 8: the switches move to KiwiHub's View side; the menu
    /// keeps its warnings, Settings, What's New, Updates and Quit.
    @Test("one KiwiHub row stands in for the switch rows")
    func hubRowReplacesSwitches() {
        reset()
        let rows = titles(controller())
        #expect(rows.contains("Open KiwiHub…"))
        for gone in [
            "Layout", "Switch Profile", "KiwiVision", "View Shortcuts…",
        ] {
            #expect(!rows.contains(gone), "\(gone) is back")
        }
        #expect(!rows.contains { $0.hasPrefix("Profile: ") })
        #expect(
            rows.filter { !$0.isEmpty } == [
                "Open KiwiHub…", "Settings…", "Quit KiwiDesk",
            ]
        )
    }

    @Test("a click opens KiwiHub once; a keyDown duplicate does not")
    func hubRowOpens() {
        reset()
        let controller = controller()
        var opened = 0
        controller.onOpenKiwiHub = { opened += 1 }
        func fire() {
            let menu = NSMenu()
            controller.menuNeedsUpdate(menu)
            let item = menu.items.first { $0.title == "Open KiwiHub…" }
            _ = item?.target?.perform(item?.action, with: item)
        }
        controller.menuActionIsKeyDown = { true }
        fire()
        #expect(opened == 0, "Carbon already fired the chord")
        controller.menuActionIsKeyDown = { false }
        fire()
        #expect(opened == 1)
    }

    @Test("the KiwiHub chord uses the native menu column")
    func hubNativeEquivalent() {
        reset()
        let controller = controller()
        controller.kiwiHubComboProvider = {
            KeyCombo(
                keyCode: 37,
                modifiers: [.control, .option]
            )
        }
        let menu = NSMenu()

        controller.menuNeedsUpdate(menu)

        let item = menu.items.first { $0.title == "Open KiwiHub…" }
        #expect(item?.keyEquivalent == "l")
        #expect(item?.keyEquivalentModifierMask == [.control, .option])
        #expect(item?.attributedTitle == nil)
    }

    /// The Settings row shows the LIVE global chord where one is
    /// bound (#1381) and the app menu's `⌘,` otherwise — the
    /// only Settings chord the menu used to teach was the one
    /// that needs a KiwiDesk window key.
    @Test("settings row renders the bound global chord")
    func settingsNativeEquivalent() {
        reset()
        let controller = controller()
        var menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        var item = menu.items.first { $0.title == "Settings…" }
        #expect(item?.keyEquivalent == ",")
        #expect(item?.keyEquivalentModifierMask == [.command])

        controller.settingsComboProvider = {
            KeyCombo(keyCode: 43, modifiers: [.control, .option])
        }
        menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        item = menu.items.first { $0.title == "Settings…" }
        #expect(item?.keyEquivalent == ",")
        #expect(item?.keyEquivalentModifierMask == [.control, .option])
    }

    /// The action behind that row drops AppKit's duplicate keyDown
    /// only where a Carbon chord already fired — with `⌘,` alone
    /// the keyDown IS the row's path.
    @Test("settings action drops the keyDown twin of a bound chord")
    func settingsActionDropsCarbonTwin() {
        reset()
        let controller = controller()
        var opened = 0
        controller.onOpenDashboard = { opened += 1 }
        func fire() {
            let menu = NSMenu()
            controller.menuNeedsUpdate(menu)
            let item = menu.items.first { $0.title == "Settings…" }
            _ = item?.target?.perform(item?.action, with: item)
        }
        controller.menuActionIsKeyDown = { true }
        fire()
        #expect(opened == 1, "⌘, keyDown is the only path")
        controller.settingsComboProvider = {
            KeyCombo(keyCode: 43, modifiers: [.control, .option])
        }
        fire()
        #expect(opened == 1, "Carbon already fired the bound chord")
        controller.menuActionIsKeyDown = { false }
        fire()
        #expect(opened == 2, "a click still opens")
    }

    @Test("native column covers every special-key glyph")
    func shortcutsSpecialEquivalents() {
        reset()
        let specialCodes = (0...127).compactMap { value -> UInt32? in
            let code = UInt32(value)
            return ComboSymbols.specialKeyGlyph(code) == nil
                ? nil : code
        }
        #expect(!specialCodes.isEmpty)
        for code in specialCodes {
            let controller = controller()
            controller.kiwiHubComboProvider = {
                KeyCombo(keyCode: code, modifiers: [.control])
            }
            let menu = NSMenu()

            controller.menuNeedsUpdate(menu)

            let item = menu.items.first {
                $0.title == "Open KiwiHub…"
            }
            #expect(
                item?.keyEquivalent.count == 1,
                "virtual key code \(code)"
            )
            #expect(
                item?.keyEquivalentModifierMask == [.control]
            )
        }
    }
}
