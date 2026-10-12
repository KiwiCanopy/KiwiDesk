import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The #952 order inside `PanelHandBack.release`: the target is
/// consumed BEFORE `orderOut`, whose resign-key re-enters the
/// close. A test has no real key panel to re-enter, so the
/// re-entry is staged inside the `orderOut` closure itself.
@Suite("Key panel hand-back order")
@MainActor
struct PanelHandBackTests {
    @Test("a close re-entered from orderOut still yields once")
    func reentrantCloseYieldsOnce() {
        let handBack = PanelHandBack(core: makeTestCore())
        let target = NSRunningApplication.current
        handBack.returnTarget = target
        handBack.isAppActive = { true }
        var yielded: [pid_t] = []
        handBack.activateReturnTarget = {
            yielded.append($0.processIdentifier)
        }
        var inner: NSRunningApplication?
        let outer = handBack.release(
            yielding: true,
            distrusting: true
        ) {
            // The resign-key close AppKit fires inside orderOut.
            inner = handBack.release(
                yielding: false,
                distrusting: false
            ) {}
        }
        #expect(outer === target)
        #expect(inner == nil)
        #expect(yielded == [target.processIdentifier])
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

    @Test("a non-activating panel answers the menu chords itself")
    func menuChords() {
        let map = PanelKeyEquivalents.action
        #expect(map("w", .command) == #selector(NSWindow.performClose(_:)))
        #expect(map("v", .command) == #selector(NSText.paste(_:)))
        #expect(map("a", .command) == #selector(NSText.selectAll(_:)))
        #expect(map("Z", [.command, .shift]) == Selector(("redo:")))
        #expect(map("v", []) == nil)
        #expect(map("w", [.command, .option]) == nil)
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
