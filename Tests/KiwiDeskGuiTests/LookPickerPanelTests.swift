import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The look picker's panel is a second non-activating key panel
/// (#3038): borderless, so it validates and answers File ▸ Close
/// itself (#1533), claims ⌘S before any menu, and swallows the
/// chords a KiwiDesk menu holds, so ⌘Q aimed at the app in front
/// never quits KiwiDesk (owner ruling 2026-10-13).
@Suite("Look picker panel (#3038)")
@MainActor
struct LookPickerPanelTests {
    private func chord(
        _ key: String,
        _ code: UInt16,
        flags: NSEvent.ModifierFlags = .command
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: code
        )!
    }

    @Test("the borderless panel validates and answers Close")
    func closeVerdict() {
        let panel = LookPickerController(core: makeTestCore())
            .makePanel()
        #expect(!panel.styleMask.contains(.closable))
        var closed = 0
        panel.onClose = { closed += 1 }
        let close = NSMenuItem(
            title: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        #expect(panel.validateUserInterfaceItem(close))
        panel.performClose(nil)
        #expect(closed == 1)
    }

    @Test("⌘S is the panel's; the app menus' chords are swallowed")
    func chords() {
        let bar = MainMenu.make(
            settingsTarget: NSObject(),
            settingsAction: #selector(NSObject.description)
        )
        let panel = LookPickerController(core: makeTestCore())
            .makePanel()
        panel.keyedForTesting = true
        var keys: [LookPickerKey] = []
        panel.onKey = { key, _ in keys.append(key) }
        let old = NSApplication.shared.mainMenu
        NSApplication.shared.mainMenu = bar
        defer { NSApplication.shared.mainMenu = old }
        #expect(panel.performKeyEquivalent(with: chord("s", 1)))
        #expect(keys == [.save])
        #expect(panel.performKeyEquivalent(with: chord("q", 12)))
        #expect(panel.performKeyEquivalent(with: chord("h", 4)))
        #expect(keys == [.save])
        panel.keyedForTesting = false
        _ = panel.performKeyEquivalent(with: chord("s", 1))
        #expect(keys == [.save], "not key, the panel claims nothing")
    }

    @Test("the reveal ends on a key or a release, never a press")
    func revealInput() {
        typealias Panel = LookPickerPanel
        #expect(Panel.duringReveal(.keyDown) == .interrupt)
        #expect(Panel.duringReveal(.leftMouseUp) == .interrupt)
        #expect(Panel.duringReveal(.rightMouseUp) == .interrupt)
        #expect(Panel.duringReveal(.leftMouseDown) == .swallow)
        #expect(Panel.duringReveal(.otherMouseDown) == .swallow)
        #expect(Panel.duringReveal(.rightMouseDown) == .swallow)
        #expect(Panel.duringReveal(.otherMouseUp) == .interrupt)
        #expect(Panel.duringReveal(.mouseMoved) == .pass)
    }

    /// A controller whose panel really orders in, its delays held.
    private func shown() -> (
        LookPickerController, () -> Void
    ) {
        let controller = LookPickerController(core: makeTestCore())
        var later: [@MainActor () -> Void] = []
        controller.after = { _, work in later.append(work) }
        controller.reduceMotion = { true }
        controller.handBack.nextTurn = { $0() }
        controller.handBack.orderFrontKey = { $0.orderFrontRegardless() }
        controller.show()
        return (
            controller,
            {
                let due = later
                later = []
                due.forEach { $0() }
            }
        )
    }

    @Test("a click's close holds the panel unseen, then orders it out")
    func clickHold() throws {
        let (controller, runLater) = shown()
        defer { controller.close() }
        let panel = try #require(controller.panel)
        #expect(controller.isOpen)
        controller.clickHold = { _ in 0.3 }
        controller.close()
        #expect(!controller.isOpen, "closed for the shortcut at once")
        #expect(panel.isVisible, "still up for the release")
        #expect(panel.alphaValue == PanelPresence.holdAlpha)
        runLater()
        #expect(!panel.isVisible)
        #expect(panel.alphaValue == 1)
        #expect(panel.contentView == nil)
        controller.clickHold = { _ in 0 }
        controller.show()
        controller.close()
        #expect(!panel.isVisible, "no click, no hold")
    }

    @Test("a reopen during the hold keeps the panel up")
    func reopenDuringHold() throws {
        let (controller, runLater) = shown()
        defer { controller.close() }
        let panel = try #require(controller.panel)
        controller.clickHold = { _ in 0.3 }
        controller.close()
        controller.show()
        runLater()
        #expect(controller.isOpen)
        #expect(panel.isVisible)
        #expect(panel.alphaValue == 1)
        #expect(panel.contentView != nil)
    }

    @Test("a key during the reveal reaches the interrupt")
    func revealWiring() {
        let panel = LookPickerController(core: makeTestCore())
            .makePanel()
        var interrupted = 0
        var keys = 0
        panel.revealing = { true }
        panel.onInterrupt = { interrupted += 1 }
        panel.onKey = { _, _ in keys += 1 }
        panel.sendEvent(chord("x", 7, flags: []))
        #expect(interrupted == 1)
        #expect(keys == 0)
    }

    @Test("an outside settings change repaints the cards")
    func liveSettings() throws {
        let (controller, _) = shown()
        defer { controller.close() }
        var settings = TilingSettings()
        settings.borderStyle.focusedColor = "#123456"
        controller.settingsChanged(settings)
        #expect(controller.model?.settings == settings)
    }
}
