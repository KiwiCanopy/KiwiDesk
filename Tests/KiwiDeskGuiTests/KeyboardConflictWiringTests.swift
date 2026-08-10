import Foundation
import Testing

@testable import KiwiDesk

/// The board's conflict-class surfacing wires (owner rulings
/// 2026-08-10), pinned by needles through the branch bodies —
/// guard-prover reverted both with every suite green before
/// these existed (the Monitors lesson, again): a surfacing
/// decision ends in an `if` inside a `body`, and nothing above
/// it can see the `if` deleted.
@Suite("Keyboard conflict surfacing wires")
struct KeyboardConflictWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static let needles: [String: [String]] = [
        "Components/Keybindings/KeyboardBoard.swift": [
            // A bound key whose combo macOS reserves rings the
            // SAME solid conflict red as an own-row collision
            // (the overwrite is conflict-class) — needle runs
            // through the stroke so a branch that stops
            // drawing red reds.
            "ifisConflicted||(isReserved&&state==.bound){"
        ],
        "Components/Keybindings/KeyboardPreviewPanel.swift": [
            // The red legend entry exists only while a red
            // ring is on the board (the caption rule applied
            // to a legend) — needle through the gate AND the
            // swatch it draws.
            "if!collisions.isEmpty||overwritesReserved{"
                + "lineSwatch(SettingsTheme.keyConflict"
        ],
    ]

    @Test("both conflict-class wires survive in their bodies")
    func wiresAreDrawn() throws {
        for (file, wants) in Self.needles {
            let url = Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/\(file)"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            #expect(!wants.isEmpty)
            for want in wants {
                #expect(
                    source.contains(want),
                    Comment(
                        rawValue:
                            "\(file) lost its conflict wire: "
                            + want
                    )
                )
            }
        }
    }
}
