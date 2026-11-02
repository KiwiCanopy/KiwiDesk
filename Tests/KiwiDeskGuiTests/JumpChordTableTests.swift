import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A modifier + ↩ on KiwiHub's Windows side picks what the same
/// modifier + click picks, through the one `JumpPick.of` table
/// (#2931 ▸ Ruling): ⌘ never changes the pick, any ⌃ picks nothing,
/// and a chord that picks nothing beeps rather than refusing.
@MainActor
@Suite("KiwiHub's one chord table")
struct JumpChordTableTests {
    private static let modifiers: [NSEvent.ModifierFlags] = [
        .shift, .control, .option, .command,
    ]

    /// Every combination of ⇧⌃⌥⌘, the empty one included.
    private var combinations: [NSEvent.ModifierFlags] {
        (0..<16).map { bits in
            var flags: NSEvent.ModifierFlags = []
            for (index, flag) in Self.modifiers.enumerated()
            where bits & (1 << index) != 0 {
                flags.insert(flag)
            }
            return flags
        }
    }

    private func returnKey(
        _ modifiers: NSEvent.ModifierFlags
    ) -> JumpKey? {
        JumpKey.of(
            keyCode: JumpKey.returnKey,
            modifiers: modifiers,
            naming: false
        )
    }

    @Test("↩ resolves through JumpPick.of for all 16 chords")
    func returnReadsTheTable() {
        #expect(combinations.count == 16)
        for held in combinations {
            let pick = JumpPick.of(held)
            let expected: JumpKey =
                switch pick {
                case .jump: .pick(moveHere: false)
                case .moveHere: .pick(moveHere: true)
                case .swapHere: .swapHere
                case nil: .dead
                }
            #expect(returnKey(held) == expected, "\(held)")
            #expect(
                pick == JumpPick.of(held.subtracting(.command)),
                "⌘ changed the pick: \(held)"
            )
            if held.contains(.control) {
                #expect(pick == nil, "⌃ picked: \(held)")
            } else {
                #expect(pick != nil, "\(held)")
            }
        }
    }

    @Test("a dead chord beeps, picks nothing and refuses nothing")
    func deadChordBeeps() {
        let model = JumpModel(
            snapshot: JumpSnapshot(
                entries: [
                    JumpEntry(
                        target: .window(WindowID(1)),
                        pid: 1,
                        app: "Calculator",
                        title: "",
                        space: "2",
                        spaceIcon: nil,
                        status: .shown,
                        movesHere: true
                    )
                ],
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 6
        )
        var beeps = 0
        var picked: [JumpPick] = []
        var spoken: [String] = []
        model.onDeadKey = { beeps += 1 }
        model.onPick = { picked.append($1) }
        model.onRefuse = { spoken.append($0) }
        model.handle(.dead, repeated: false)
        #expect(beeps == 1)
        #expect(picked.isEmpty)
        #expect(spoken.isEmpty)
        #expect(model.refusedRow == nil)
    }

    @Test("a row click reads the same table")
    func clickReadsTheTable() throws {
        let row = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpRowView.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            row.contains(
                "ifletpick=JumpPick.of(NSEvent.modifierFlags){"
                    + "onActivate(pick)"
            )
        )
    }
}
