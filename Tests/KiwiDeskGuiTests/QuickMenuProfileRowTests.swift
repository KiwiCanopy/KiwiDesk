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

/// The Switch Profile quick-menu row — and the active-profile
/// context line above it — appear only when there is a profile
/// worth switching to: one that isn't the active one and isn't
/// broken. `.serialized` because `LocalizationManager` is a
/// process-wide singleton (titles are matched in English).
@Suite("Quick menu Switch Profile row", .serialized)
@MainActor
struct QuickMenuProfileRowTests {
    private func reset() {
        LocalizationManager.shared.select("en")
    }

    private func controller(
        active: String?,
        all: [String],
        broken: [String] = []
    ) -> StatusItemController {
        let controller = StatusItemController(
            item: FakeStatusItem()
        )
        controller.profilesProvider = {
            (active: active, all: all, broken: Set(broken))
        }
        return controller
    }

    private func hasSwitchRow(
        _ controller: StatusItemController
    ) -> Bool {
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        return menu.items.contains { $0.title == "Switch Profile" }
    }

    private func activeLine(
        _ controller: StatusItemController
    ) -> NSMenuItem? {
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        return menu.items.first {
            $0.title.hasPrefix("Profile: ")
        }
    }

    @Test("shortcuts combo uses the native menu column")
    func shortcutsNativeEquivalent() {
        reset()
        let controller = controller(active: nil, all: [])
        controller.shortcutsComboProvider = {
            KeyCombo(
                keyCode: 40,
                modifiers: [.control, .option]
            )
        }
        let menu = NSMenu()

        controller.menuNeedsUpdate(menu)

        let item = menu.items.first { $0.title == "View Shortcuts…" }
        #expect(item?.keyEquivalent == "k")
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
        let controller = controller(active: nil, all: [])
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
        let controller = controller(active: nil, all: [])
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
            let controller = controller(active: nil, all: [])
            controller.shortcutsComboProvider = {
                KeyCombo(keyCode: code, modifiers: [.control])
            }
            let menu = NSMenu()

            controller.menuNeedsUpdate(menu)

            let item = menu.items.first {
                $0.title == "View Shortcuts…"
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

    @Test("hidden with no profiles")
    func noProfiles() {
        reset()
        #expect(!hasSwitchRow(controller(active: nil, all: [])))
    }

    @Test("hidden when the only profile is already active")
    func loneActive() {
        reset()
        #expect(
            !hasSwitchRow(
                controller(active: "Work", all: ["Work"])
            )
        )
    }

    @Test("shown when the only profile isn't active")
    func loneInactive() {
        reset()
        #expect(
            hasSwitchRow(
                controller(active: nil, all: ["Work"])
            )
        )
    }

    @Test("hidden when the only non-active profile is broken")
    func loneBroken() {
        reset()
        #expect(
            !hasSwitchRow(
                controller(
                    active: "Work",
                    all: ["Work", "Bad"],
                    broken: ["Bad"]
                )
            )
        )
    }

    @Test("shown with two switchable profiles")
    func twoProfiles() {
        reset()
        #expect(
            hasSwitchRow(
                controller(
                    active: "Work",
                    all: ["Work", "Play"]
                )
            )
        )
    }

    // MARK: - Active-profile context line

    @Test("active line names the profile when a choice exists")
    func activeLineShown() {
        reset()
        let line = activeLine(
            controller(active: "Work", all: ["Work", "Play"])
        )
        #expect(line?.title == "Profile: Work")
        // Context only — native section header, never an action.
        #expect(line?.isSectionHeader == true)
    }

    @Test("active line hidden with only the active profile")
    func activeLineLoneProfile() {
        reset()
        #expect(
            activeLine(
                controller(active: "Work", all: ["Work"])
            ) == nil
        )
    }

    @Test("active line hidden when no profile is loaded")
    func activeLineNoActive() {
        reset()
        #expect(
            activeLine(
                controller(active: nil, all: ["Work"])
            ) == nil
        )
    }

    @Test("active line hidden when the only other is broken")
    func activeLineOnlyBrokenAlternative() {
        reset()
        #expect(
            activeLine(
                controller(
                    active: "Work",
                    all: ["Work", "Bad"],
                    broken: ["Bad"]
                )
            ) == nil
        )
    }
}
