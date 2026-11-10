import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A modifier still held from the chord that opened or stepped
/// KiwiHub does not count until it is let go (#3168): ↩ under the
/// ⌥ of ⌥⇥ jumps rather than swaps, ⇧ from ⇧⌥⇥ never moves here,
/// and ↩, the digits, a click and the lit hint read one set.
@Suite("KiwiHub opener modifiers (#3168)")
@MainActor
struct JumpStaleModifierTests {
    private func model() -> JumpModel {
        let model = JumpModel(
            snapshot: JumpStripTests.snapshot,
            icons: [:],
            rowCap: 9,
            pointer: .zero
        )
        model.currentPointer = { .zero }
        return model
    }

    private func keyDown(
        _ code: UInt16,
        _ characters: String,
        _ flags: NSEvent.ModifierFlags
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: code
        )!
    }

    private func panel(stale: NSEvent.ModifierFlags) -> JumpPanel {
        let panel = JumpPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        panel.stale = { stale }
        return panel
    }

    @Test("the opener's ⌥ counts for nothing until let go")
    func openerOptionIsStale() {
        let model = model()
        model.latchOpener([.option])
        #expect(model.pickModifiers([.option]).isEmpty)
        #expect(!model.optionHeld)
        #expect(model.heldModifiers.isEmpty)
        model.noteModifiers([])
        model.noteModifiers([.option])
        #expect(model.pickModifiers([.option]) == .option)
        #expect(model.optionHeld)
    }

    @Test("⇧ from the back step is stale; a fresh ⇧ counts")
    func shiftFromTheBackStep() {
        let model = model()
        model.latchOpener([.shift, .option])
        #expect(model.pickModifiers([.shift, .option]).isEmpty)
        // ⇧ let go and pressed again while ⌥ stays down.
        model.noteModifiers([.option])
        model.noteModifiers([.shift, .option])
        #expect(model.pickModifiers([.shift, .option]) == .shift)
        #expect(model.shiftHeld && !model.optionHeld)
    }

    @Test("each step latches what is held then")
    func stepRelatches() {
        let model = model()
        model.latchOpener([.option])
        model.noteModifiers([])
        model.latchOpener([.option])
        #expect(model.pickModifiers([.option]).isEmpty)
    }

    @Test("the lit hint is Jump while the opener's ⌥ is held")
    func footerLightsJump() {
        let model = model()
        model.latchOpener([.option])
        let stale = JumpFooter(
            scope: .windows,
            overflows: false,
            modifiers: model.heldModifiers
        )
        #expect(stale.leading == 0)
        model.noteModifiers([])
        model.noteModifiers([.option])
        let fresh = JumpFooter(
            scope: .windows,
            overflows: false,
            modifiers: model.heldModifiers
        )
        #expect(fresh.leading == 1)
    }

    @Test("↩ and a digit under a stale ⌥ jump; a fresh ⌥ swaps")
    func panelReadsPicksWithoutTheStale() {
        let ret = keyDown(36, "\r", [.option])
        let one = keyDown(18, "1", [.option, .command])
        #expect(
            panel(stale: [.option]).key(for: ret) == .pick(moveHere: false)
        )
        #expect(panel(stale: []).key(for: ret) == .swapHere)
        #expect(
            panel(stale: [.option]).key(for: one)
                == .quick(0, moveHere: false)
        )
        #expect(panel(stale: []).key(for: one) == .quickSwap(0))
    }

    @Test("a non-pick key keeps every modifier; the back chord latches")
    func otherKeysKeepTheirModifiers() {
        let panel = panel(stale: [.shift, .option])
        let chord = KeyCombo(
            keyCode: 48,
            modifiers: [.shift, .option]
        )
        panel.back = { chord }
        var latched: [NSEvent.ModifierFlags] = []
        panel.onBackChord = { latched.append($0) }
        let back = keyDown(48, "\t", [.shift, .option])
        #expect(panel.key(for: back) == .side(-1))
        #expect(latched == [[.shift, .option]])
        _ = panel.key(for: keyDown(36, "\r", [.shift, .option]))
        #expect(latched.count == 1)
    }

    /// Every opener door latches, and a click reads the same set.
    @Test("the doors latch and every reader takes the one set")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Jump")
        func squash(_ file: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(file)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let latch = "currentModel?.latchOpener(NSEvent.modifierFlags)"
        let controller = try squash("JumpPanelController.swift")
        #expect(
            controller.contains("model.latchOpener(NSEvent.modifierFlags)")
        )
        #expect(
            controller.contains(
                "case.switchScope:currentModel?.setScope(scope)" + latch
            )
        )
        #expect(
            controller.contains(
                "panel.stale={[weakmodel]inmodel?.staleModifiers??[]}"
            )
        )
        #expect(
            controller.contains(
                "panel.onBackChord={[weakmodel]inmodel?.latchOpener($0)}"
            )
        )
        let strip = try squash("JumpPanelController+Strip.swift")
        #expect(
            strip.contains(
                "currentModel?.handle(.side(1),repeated:false)" + latch
            )
        )
        #expect(strip.contains("currentModel?.openOnLastApp()" + latch))
        let row = try squash("JumpRowView.swift")
        #expect(row.contains("JumpPick.of(pickModifiers())"))
        #expect(!row.contains("JumpPick.of(NSEvent.modifierFlags)"))
        #expect(
            try squash("JumpPanelView.swift").contains(
                "pickModifiers:{model.pickModifiers(NSEvent.modifierFlags)}"
            )
        )
        let panel = try squash("JumpPanel.swift")
        // Both key doors read through the one reader.
        #expect(
            panel.components(separatedBy: "letkey=key(for:event)").count
                == 3
        )
    }
}
