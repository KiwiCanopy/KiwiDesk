import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Fake menu-bar slot, as `QuickMenuHubRowTests`' (#565-class seam).
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = nil
    var menu: NSMenu?
}

/// A menu row never promises a key its chord does not mean (#3470 ▸
/// owner, ui-designer's option a): AppKit's key-equivalent column
/// has no ✦, so a Hyper chord leaves it empty rather than drawing a
/// bare key, and its press is never taken for Carbon's twin. The
/// Desktop overview row carries its live chord as the KiwiHub row
/// does. `.serialized`: titles are matched in English.
@Suite("Status menu ▸ Hyper chords and the overview row", .serialized)
@MainActor
struct StatusMenuHyperChordTests {
    private let hyperL = KeyCombo(keyCode: 37, modifiers: [.hyper])
    private let hyperCmd3 = KeyCombo(
        keyCode: 20,
        modifiers: [.hyper, .command]
    )

    private func press(
        _ keyCode: UInt16,
        _ modifiers: NSEvent.ModifierFlags
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }

    private func menu(_ controller: StatusItemController) -> NSMenu {
        LocalizationManager.shared.select("en")
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        return menu
    }

    @Test("a Hyper chord sets no key equivalent and is never pressed")
    func hyperDrawsNothing() throws {
        for chord in [hyperL, hyperCmd3] {
            let item = NSMenuItem(
                title: "Row",
                action: nil,
                keyEquivalent: ""
            )
            chord.applyMenuEquivalent(to: item) { _ in "l" }
            #expect(item.keyEquivalent == "")
            #expect(item.keyEquivalentModifierMask == [.command])
            let bare = try #require(press(UInt16(chord.keyCode), []))
            #expect(!chord.isPressed(by: bare))
            let command = try #require(
                press(UInt16(chord.keyCode), [.command])
            )
            #expect(!chord.isPressed(by: command))
        }
    }

    @Test("the overview row draws its bound chord, and none for ✦")
    func overviewRowCarriesItsChord() {
        let controller = StatusItemController(item: FakeStatusItem())
        controller.overviewComboProvider = {
            KeyCombo(keyCode: 31, modifiers: [.control, .option])
        }
        var row = menu(controller).items.first {
            $0.title == "Show Desktop overview"
        }
        #expect(row?.keyEquivalent == "o")
        #expect(row?.keyEquivalentModifierMask == [.control, .option])
        controller.overviewComboProvider = {
            KeyCombo(keyCode: 31, modifiers: [.hyper])
        }
        row = menu(controller).items.first {
            $0.title == "Show Desktop overview"
        }
        #expect(row?.keyEquivalent == "")
    }

    @Test("the overview row drops only its chord's Carbon twin")
    func overviewDropsTheTwin() {
        let controller = StatusItemController(item: FakeStatusItem())
        controller.overviewComboProvider = {
            KeyCombo(keyCode: 31, modifiers: [.control, .option])
        }
        var opened = 0
        controller.onOpenDesktopOverview = { opened += 1 }
        func fire() {
            let item = menu(controller).items.first {
                $0.title == "Show Desktop overview"
            }
            _ = item?.target?.perform(item?.action, with: item)
        }
        controller.menuKeyDown = { [self] in press(31, [.control, .option]) }
        fire()
        #expect(opened == 0, "Carbon already fired the chord")
        controller.menuKeyDown = { [self] in press(36, []) }
        fire()
        #expect(opened == 1, "Return on the picked row opens")
    }
}
