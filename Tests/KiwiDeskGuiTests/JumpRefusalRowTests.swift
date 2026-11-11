import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A refused pick stays in KiwiHub (#2885 ▸ refusals shown in the
/// row): the row the held modifier speaks for shows ⛔ and why, a
/// refused press reaches no pick and is spoken, and the footer and
/// VoiceOver drop what would refuse.
@MainActor
@Suite("KiwiHub refusals shown in the row")
struct JumpRefusalRowTests {
    private func entry(
        swap: JumpSwapBlock? = nil,
        move: JumpMoveBlock? = nil
    ) -> JumpEntry {
        JumpEntry(
            target: .window(WindowID(1)),
            pid: 1,
            app: "Calculator",
            title: "",
            space: "2",
            spaceIcon: nil,
            status: .shown,
            movesHere: move == nil,
            swapBlock: swap,
            moveBlock: move
        )
    }

    private func model(_ entry: JumpEntry) -> JumpModel {
        JumpModel(
            snapshot: JumpSnapshot(entries: [entry], here: "1", hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
    }

    @Test("a refused pick reaches no pick and is spoken")
    func refusedPressStays() {
        LocalizationManager.shared.select("en")
        let model = model(entry(swap: .floating, move: .fullScreen))
        var picked: [JumpPick] = []
        var spoken: [String] = []
        model.onPick = { picked.append($1) }
        model.onRefuse = { spoken.append($0) }
        model.handle(.swapHere, repeated: false)
        #expect(model.refusedRow == 0)
        model.clickRow(0, pick: .moveHere)
        model.handle(.quick(0, moveHere: true), repeated: false)
        #expect(picked.isEmpty)
        #expect(
            spoken == [
                "Can't swap: Floating",
                "Can't move here: Full Screen",
                "Can't move here: Full Screen",
            ]
        )
        model.handle(.quickSwap(0), repeated: false)
        #expect(spoken.last == "Can't swap: Floating")
        #expect(model.revealedRow == 0)
        // A jump is never refused here.
        model.handle(.pick(moveHere: false), repeated: false)
        #expect(picked == [.jump])
        model.noteModifiers([])
        #expect(model.revealedRow == nil)
        // A row out of the list picks nothing and traps nothing.
        model.clickRow(5, pick: .swapHere)
        #expect(picked == [.jump])
    }

    /// Core answers at the press (Ruling 4): a row the snapshot
    /// refused that now goes ahead reaches the verb.
    @Test("the press asks Core, not the snapshot")
    func pressAsksCore() {
        let model = model(entry(swap: .floating))
        var picked: [JumpPick] = []
        model.onPick = { picked.append($1) }
        model.swapRefusal = { _ in nil }
        model.handle(.swapHere, repeated: false)
        #expect(picked == [.swapHere])
    }

    @Test("the controller wires Core's reads, sound and words")
    func controllerWiring() throws {
        let source = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpPanelController.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(source.contains("self?.core.soundPanelRefusal()"))
        // The one door that sounds without a hotkey fire answers
        // KiwiHub's in-panel refusal alone.
        var sounders = 0
        for file in try SourceScan.swiftSources(
            under: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk")
        ) {
            sounders += try SourceScan.blankedSource(at: file)
                .occurrences(of: "soundPanelRefusal()")
        }
        #expect(sounders == 1)
        #expect(source.contains("model?.onAnnounce(spoken)"))
        #expect(source.contains("model.onDeadKey={NSSound.beep()}"))
        #expect(
            source.contains(
                "self?.core.swapRefusal(entry.target,on:self?.hubDisplay)"
            )
        )
        #expect(
            source.contains(
                "self?.core.moveHereRefusal(entry.target,on:self?.hubDisplay)"
            )
        )
        // Every Windows pick passes the one door (`JumpModel.pick`).
        let model = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpModel.swift"
                )
        )
        #expect(model.occurrences(of: "onPick(") == 0)
        // A refused row offers no row action.
        let row = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpRowView.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            row.contains("offered:!entry.isHiddenApp&&entry.moveBlock==nil")
        )
        #expect(row.contains("offered:entry.swapBlock==nil"))
    }

    @Test("a pick the snapshot allows goes ahead")
    func allowedPressPicks() {
        let model = model(entry())
        var picked: [JumpPick] = []
        model.onPick = { picked.append($1) }
        model.onRefuse = { _ in Issue.record("refused") }
        model.handle(.swapHere, repeated: false)
        model.clickRow(0, pick: .moveHere)
        #expect(picked == [.swapHere, .moveHere])
        #expect(model.refusedRow == nil)
    }

    @Test("both families of reason are worded")
    func reasonsAreWorded() {
        LocalizationManager.shared.select("en")
        #expect(JumpRowText.refusal(JumpSwapBlock.floating) == "Floating")
        #expect(
            JumpRowText.refusal(JumpSwapBlock.yoursFloating)
                == "Yours is floating"
        )
        #expect(JumpRowText.refusal(.otherDesktop(2)) == "Desktop 2")
        #expect(JumpRowText.refusal(JumpMoveBlock.sticky) == "Sticky")
    }

    private func row(
        owns: Bool,
        shift: Bool = false,
        option: Bool = false,
        command: Bool = false,
        number: Int? = 1
    ) -> JumpRowView {
        let match = JumpSearch.matches([entry()], query: "")[0]
        return JumpRowView(
            match: match,
            icon: nil,
            isSelected: owns,
            ownsShift: owns,
            ownsOption: owns,
            number: number,
            commandHeld: command,
            shiftHeld: shift,
            optionHeld: option,
            wayHere: nil,
            refusal: JumpRowRefusal(swap: "Floating", move: "Sticky"),
            onActivate: { _ in },
            pickModifiers: { [] }
        )
    }

    @Test("the reason shows on the row its modifier speaks for")
    func reasonFollowsTheModifier() {
        #expect(row(owns: true, option: true).shownRefusal == "Floating")
        #expect(
            row(owns: true, shift: true, option: true).shownRefusal
                == "Floating"
        )
        #expect(row(owns: true, shift: true).shownRefusal == "Sticky")
        #expect(row(owns: false, option: true).shownRefusal == nil)
        #expect(row(owns: false, shift: true).shownRefusal == nil)
        // ⇧⌘ reaches every numbered row, as its way here does.
        #expect(
            row(owns: false, shift: true, command: true).shownRefusal
                == "Sticky"
        )
        #expect(row(owns: true).shownRefusal == nil)
    }

    @Test("a refused selection lights nothing under ⇧")
    func footerUnderShift() {
        let footer = JumpFooter(
            scope: .windows,
            overflows: false,
            modifiers: .shift,
            selectionMoves: false
        )
        #expect(footer.leading == nil)
    }
}
