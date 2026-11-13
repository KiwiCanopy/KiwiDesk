import Foundation
import Testing

@testable import KiwiDesk

/// A key sequence row's marks (#3241): the fold sits before a
/// branch's key and outside its container, other keys keep its slot,
/// a branch leads with the layer symbol and ends with a pencil inside
/// its one button, an action leads with its catalogue glyph, and a
/// Lua key leads with Lua's mark and ends with the expand glyph.
@Suite("Key sequence row marks (#3241)")
struct KeySequenceRowMarksTests {
    private static let dir =
        "Sources/KiwiDesk/Settings/Components/"
        + "Keybindings/Sequences/"

    private static func flat(_ name: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(dir + name)
        )
        .filter { !$0.isWhitespace }
    }

    private static func body(
        _ declaration: String,
        in name: String
    ) throws -> String {
        let raw = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(dir + name)
        )
        let body = try #require(
            SourceScan.declarationBody(after: declaration, in: raw)
        )
        return body.filter { !$0.isWhitespace }
    }

    @Test("The fold leads a branch's key line, a slot leads the rest")
    func foldLeadsTheKey() throws {
        let line = try Self.body(
            "@ViewBuilder private var keyLine:",
            in: "SequenceNodeRow.swift"
        )
        #expect(!line.isEmpty)
        #expect(
            line.hasPrefix(
                "ifnode.isSequence{disclosure(width:Self.foldSlot)"
            )
        )
        #expect(
            line.contains("}else{Color.clear.frame(width:Self.foldSlot,")
        )
        let fold = try #require(line.range(of: "disclosure("))
        let key = try #require(line.range(of: "recorder.fixedSize()"))
        #expect(fold.lowerBound < key.lowerBound)
        let branch = try Self.body(
            "var branchContainer:",
            in: "SequenceNodeRow+Popovers.swift"
        )
        #expect(!branch.contains("disclosure("))
    }

    @Test("A branch's one button leads with the layer and ends in a pencil")
    func branchMarks() throws {
        let branch = try Self.body(
            "var branchContainer:",
            in: "SequenceNodeRow+Popovers.swift"
        )
        #expect(
            branch.contains(
                "Button{editingBranch=SequenceBranchRequest(id:node.id)"
                    + "}label:{HStack(spacing:4){"
                    + "Image(systemName:Self.branchSymbol)"
            )
        )
        // The pencil follows the name inside the button's label.
        #expect(
            branch.contains(
                "branchTitle.fixedSize(horizontal:true,vertical:false)"
                    + "Image(systemName:\"pencil\")"
            )
        )
        // One button: the pencil sits inside the label it opens.
        #expect(branch.components(separatedBy: "Button{").count == 2)
        // The marks are decorative; the button keeps its name.
        #expect(
            branch.contains(
                "Image(systemName:Self.branchSymbol).accessibilityHidden(true)"
            )
        )
        #expect(
            branch.contains(
                "Image(systemName:\"pencil\")"
                    + ".foregroundStyle(SettingsTheme.ink2)"
                    + ".accessibilityHidden(true)"
            )
        )
        #expect(
            branch.contains(
                ".buttonStyle(.plain).accessibilityLabel(nameLabel)"
                    + ".accessibilityValue(node.label)"
            )
        )
    }

    @Test("A trigger leads with its kind's mark; Lua ends in expand")
    func triggerMarks() throws {
        let trigger = try Self.body(
            "@ViewBuilder var trigger:",
            in: "SequenceActionMenu+Trigger.swift"
        )
        #expect(
            trigger.contains(
                "ifmarksKind{Image(systemName:Self.luaSymbol)"
            )
        )
        let name = try #require(trigger.range(of: "Text(title)"))
        let expand = try #require(
            trigger.range(
                of: "Image(systemName:\"arrow.up.left.and.arrow.down.right\")"
            )
        )
        #expect(name.lowerBound < expand.lowerBound)
        #expect(trigger.contains("appIconcommandGlyphText(title)"))
        #expect(
            trigger.contains(
                "Image(systemName:Self.luaSymbol).accessibilityHidden(true)"
            )
        )
        #expect(
            trigger.contains(
                "arrow.down.right\").font(.caption2)"
                    + ".foregroundStyle(SettingsTheme.ink2)"
                    + ".accessibilityHidden(true)"
            )
        )
        let glyph = try Self.body(
            "@ViewBuilder var commandGlyph:",
            in: "SequenceActionMenu+Trigger.swift"
        )
        #expect(
            glyph.contains("ifmarksKind,bundleID==nil,")
                && glyph.contains(
                    "ShortcutsReferenceBuilder.icon(for:command)"
                )
                && glyph.contains("ShortcutGlyphView(glyph:glyph)")
        )
        let row = try Self.flat("SequenceNodeRow.swift")
        #expect(row.contains("marksKind:true,"))
    }
}
