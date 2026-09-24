import Foundation
import Testing

/// A glyph-only icon control rests as the bare glyph and shows its
/// chip on hover (#1393): one chip, `iconHoverChip`, reached by the
/// icon affordance, the `?` and both branches of the rule trash.
@Suite("Icon hover chip (#1393)")
struct IconHoverChipTests {
    private func source(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
    }

    private func body(of name: String, in source: String) -> String {
        guard let start = source.range(of: "func \(name)(") else {
            return ""
        }
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\n    func ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    @Test("the chip rests at nothing, and the icon affordance takes it")
    func chipRestsAtNothing() throws {
        let rows = try source("Components/Common/SettingsRows.swift")
        let chip = body(of: "iconHoverChip", in: rows)
        #expect(chip.contains("restOpacity: 0,"))
        #expect(chip.contains("tint(SettingsTheme.ink2)"))
        #expect(
            body(of: "iconButtonAffordance", in: rows).contains(
                "iconHoverChip("
            )
        )
    }

    @Test("the ? and both rule-trash branches take the one chip")
    func everyIconTakesIt() throws {
        let help = try source("Components/Common/HelpButton.swift")
        #expect(help.contains(".iconHoverChip()"))
        #expect(!help.contains(".hoverHighlight("))
        let trash = try source("Sections/AppRuleIdentity.swift")
        #expect(trash.occurrences(of: ".iconHoverChip()") == 1)
        // The menu's own neutral label ink sits closer to the glyph.
        #expect(trash.contains(".foregroundStyle(SettingsTheme.ink2)"))
        #expect(trash.occurrences(of: ".iconButtonAffordance(") == 1)
    }
}
