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

    /// Each arm of the way here past the source draws only while
    /// expanded: ungated, every row shows `→ here` without ⇧.
    @Test("the way here past the source draws only while expanded")
    func wayHereArmsAreGated() throws {
        let view = try squashed("JumpPlaceView.swift")
        #expect(view.contains("case.text(letliteral):ifexpanded{"))
        #expect(view.contains("case.argument(2):ifexpanded{"))
        #expect(view.components(separatedBy: "ifexpanded{").count == 3)
    }

    /// Layout Defaults… hands focus to Settings, which the #952
    /// grace would eat as a dismiss blip: its close arms nothing.
    @Test("Layout Defaults closes the panel without the distrust")
    func layoutDefaultsArmsNoDistrust() throws {
        let wiring = try squashed("JumpPanelController+Layouts.swift")
        #expect(
            wiring.contains(
                "self.dismiss(distrusting:false)else{return}"
                    + "self.core.barMenuHooks.openSettings("
            )
        )
    }
}
