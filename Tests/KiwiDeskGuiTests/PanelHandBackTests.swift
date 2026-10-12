import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The shared key-panel layer: a close arms the dismiss distrust
/// BEFORE `orderOut`, whose resign-key re-enters the close (#952);
/// a show keys the panel a turn later and never activates.
@Suite("Key panel show and close")
@MainActor
struct PanelHandBackTests {
    @Test("the distrust is armed before the order-out")
    func distrustBeforeOrderOut() {
        let core = makeTestCore()
        let handBack = PanelHandBack(core: core)
        handBack.isAppActive = { true }
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        var armedAtOrderOut: Bool?
        handBack.release(distrusting: true) {
            armedAtOrderOut = core.ignoredPanel.active.contains(own)
        }
        #expect(armedAtOrderOut == true)
    }

    @Test("a close that came first leaves the deferred key unsent")
    func closeBeforeKeyWins() {
        let handBack = PanelHandBack(core: makeTestCore())
        var keyed = 0
        handBack.orderFrontKey = { _ in keyed += 1 }
        var deferred: [() -> Void] = []
        handBack.nextTurn = { deferred.append($0) }
        let wanted = Flag()
        handBack.present(NSPanel()) { wanted.value }
        wanted.value = false
        deferred.forEach { $0() }
        #expect(keyed == 0)
    }

    /// The panel is keyed and nothing else: no activation, so no
    /// own window is raised and no distrust is left armed.
    @Test("present keys the panel and arms nothing")
    func presentOnlyKeys() {
        let core = makeTestCore()
        let handBack = PanelHandBack(core: core)
        var keyed: [NSWindow] = []
        handBack.orderFrontKey = { keyed.append($0) }
        var deferred: [() -> Void] = []
        handBack.nextTurn = { deferred.append($0) }
        let panel = NSPanel()
        handBack.present(panel)
        // Never in the opening turn, which a menu's close undoes.
        #expect(keyed.isEmpty)
        deferred.forEach { $0() }
        #expect(keyed.count == 1 && keyed.first === panel)
        #expect(core.ignoredPanel.active.isEmpty)
    }

    @Test("both key panels are non-activating")
    func panelsAreNonActivating() {
        let core = makeTestCore()
        let jump = JumpPanelController(core: core).makePanel()
        let sheet = ShortcutsPanelController(core: core, onEdit: {})
            .makePanel()
        #expect(jump.styleMask.contains(.nonactivatingPanel))
        #expect(sheet.styleMask.contains(.nonactivatingPanel))
    }

    /// A non-activating panel's app is not the one in the menu
    /// bar, so both hand their chords to KiwiDesk's main menu —
    /// ⌘W's Close (#1533) and the edit chords, one table.
    @Test("both panels hand their chords to the main menu")
    func chordsReachTheMainMenu() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        for path in [
            "Sources/KiwiDesk/Jump/JumpPanel.swift",
            "Sources/KiwiDesk/Shortcuts/ShortcutsPanelController.swift",
        ] {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(path),
                    encoding: .utf8
                )
            ).replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\n", with: "")
            #expect(!source.isEmpty)
            #expect(
                source.contains("mainMenu?.performKeyEquivalent(with:event"),
                "\(path)"
            )
        }
    }

    /// Both key panels open through the one door.
    @Test("both panels present through the hand-back")
    func panelsPresentThroughTheDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        for path in [
            "Sources/KiwiDesk/Jump/JumpPanelController.swift",
            "Sources/KiwiDesk/Shortcuts/ShortcutsPanelController.swift",
        ] {
            let raw = try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
            let source = SourceScan.stripComments(raw)
            #expect(!source.isEmpty)
            #expect(source.contains("handBack.present(panel)"), "\(path)")
            #expect(!source.contains(".activate("), "\(path)")
            #expect(!source.contains("makeKeyAndOrderFront"), "\(path)")
        }
    }
}

@MainActor
private final class Flag {
    var value = true
}
