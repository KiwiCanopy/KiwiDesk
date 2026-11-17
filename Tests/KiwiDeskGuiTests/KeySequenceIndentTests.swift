import Foundation
import Testing

@testable import KiwiDesk

/// The Key sequences card's outline (#3425 ▸ Ruling): every level
/// steps in one 18 pt fold slot, the leader's fold included; a rail
/// sits centred in its keys' step and adds no width; past
/// `indentCap` a branch's keys list flat under the shortened path;
/// a rule parts two sequences; and a pill's title is the one part
/// that truncates. Source needles, whitespace stripped, since a
/// SwiftUI layout leaves nothing a headless test can read.
@Suite("Key sequence indent (#3425)")
struct KeySequenceIndentTests {
    private static let dir =
        "Sources/KiwiDesk/Settings/Components/"
        + "Keybindings/Sequences/"

    private static func flat(_ path: String) throws -> String {
        let text = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
        )
        .filter { !$0.isWhitespace }
        #expect(!text.isEmpty)
        return text
    }

    @Test("every level steps one fold slot")
    @MainActor
    func evenStep() throws {
        #expect(SequenceNodeRow.foldSlot == SettingsMetrics.shortcutIconSlot)
        let row = try Self.flat(Self.dir + "SequenceNodeRow.swift")
        // The leader's fold is a key line's, and nothing insets its
        // chord.
        #expect(row.occurrences(of: "disclosure(width:Self.foldSlot)") == 2)
        #expect(!row.contains("leaderKeyInset"))
        // The rail is an overlay in the step, never padded beside it.
        #expect(
            row.contains(
                "Color.clear.frame(width:Self.foldSlot).overlay{"
                    + "SettingsTheme.hairlineSubtle"
                    + ".frame(width:Self.railWidth)}"
            )
        )
        #expect(!row.contains("shortcutIconSlot/2"))
    }

    @Test("past the cap a branch's keys list flat under its path")
    @MainActor
    func deepKeysFlat() throws {
        #expect(SequenceNodeRow.indentCap == 4)
        let row = try Self.flat(Self.dir + "SequenceNodeRow.swift")
        #expect(
            row.contains(
                "privatevarkeysFlat:Bool{path.count-1>=Self.indentCap}"
            )
        )
        #expect(row.contains("if!keysFlat{Color.clear"))
        #expect(row.contains("ifkeysFlat{flatCaption}ForEach("))
        #expect(row.contains("path:path+[step.combo],"))
        #expect(row.contains("Text(SequencePathWords.shortened(path))"))
        #expect(
            row.contains(
                ".padding(.leading,SettingsMetrics.shortcutTextIndent)"
                    + ".help(SequencePathWords.spoken(path))"
                    + ".accessibilityLabel(SequencePathWords.spoken(path))"
            )
        )
        let card = try Self.flat(
            "Sources/KiwiDesk/Settings/Sections/KeySequencesCard.swift"
        )
        #expect(card.contains("path:[sequence.combo],"))
    }

    @Test("a rule parts two sequences, none above Add Sequence")
    func divider() throws {
        let card = try Self.flat(
            "Sources/KiwiDesk/Settings/Sections/KeySequencesCard.swift"
        )
        #expect(
            card.contains(
                "ifindex>0{SettingsTheme.hairlineSubtle.frame(height:1)"
                    + ".padding(.vertical,10)"
            )
        )
        #expect(card.occurrences(of: "hairlineSubtle") == 1)
    }

    @Test("a pill's title truncates and the chord never does")
    func titleGivesWay() throws {
        let trigger = try Self.flat(
            Self.dir + "SequenceActionMenu+Trigger.swift"
        )
        #expect(
            trigger.contains(
                "privatevartitleText:someView{Text(title).lineLimit(1)"
                    + ".truncationMode(.tail)}"
            )
        )
        #expect(trigger.occurrences(of: "titleText") == 3)
        #expect(trigger.occurrences(of: ".help(title)") == 2)
        #expect(!trigger.contains(".fixedSize(horizontal:true"))
        let branch = try Self.flat(
            Self.dir + "SequenceNodeRow+Popovers.swift"
        )
        #expect(
            branch.contains(
                "branchTitle.lineLimit(1).truncationMode(.tail)"
                    + "Image(systemName:\"pencil\")"
            )
        )
        #expect(branch.contains(".buttonStyle(.plain).help(node.label)"))
        #expect(!branch.contains("branchTitle.fixedSize("))
        let row = try Self.flat(Self.dir + "SequenceNodeRow.swift")
        #expect(
            row.occurrences(of: "recorder.fixedSize().layoutPriority(1)")
                == 2
        )
        #expect(
            row.contains(
                "KeyReachColumn(model:model,layer:layerName,binding:node)"
                    + ".layoutPriority(1)"
            )
        )
    }
}
