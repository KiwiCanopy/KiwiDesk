import Foundation
import Testing

@testable import KiwiDesk

/// Two Jump panel gates no rendered test reaches (#1875): the
/// field's typing drawn clear while the selected name stands in
/// for it, and the way here's connective and destination drawn
/// only while ⇧ expands the row.
@Suite("Jump to window view gates")
struct JumpViewGateTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func squashed(_ file: String) throws -> String {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Jump/\(file)"
        )
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// The typed glyphs AND the caret go clear under the stand-in,
    /// or both show through the selected name. The inks are glue
    /// holding the needle contiguous on the field's own chain.
    @Test("the field's typing is drawn clear under the stand-in")
    func fieldTypingIsClear() throws {
        let view = try squashed("JumpPanelView.swift")
        #expect(
            view.contains(
                ".font(.largeTitle)"
                    + ".foregroundStyle(model.field==nil"
                    + "?Color.primary:Color.clear)"
                    + ".tint(model.field==nil"
                    + "?SettingsTheme.accent:.clear)"
            )
        )
    }

    /// Each arm of the way here past the source draws only while
    /// expanded: ungated, every row shows `→ here` without ⇧.
    @Test("the way here past the source draws only while expanded")
    func wayHereArmsAreGated() throws {
        let view = try squashed("JumpPlaceView.swift")
        #expect(view.contains("case.text(letliteral):ifexpanded{"))
        #expect(view.contains("case.argument(2):ifexpanded{"))
        #expect(view.components(separatedBy: "ifexpanded{").count == 3)
    }
}
