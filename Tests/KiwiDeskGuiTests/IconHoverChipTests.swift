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
        #expect(chip.contains("restOpacity: resting ? 0.06 : 0,"))
        #expect(chip.contains("resting: Bool = false"))
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
        #expect(help.contains(".iconHoverChip(cornerRadius: 8, padding: 0)"))
        #expect(!help.contains(".hoverHighlight("))
        let trash = try source("Sections/AppRuleIdentity.swift")
        #expect(trash.occurrences(of: ".iconHoverChip()") == 1)
        // The menu's own neutral label ink sits closer to the glyph.
        #expect(trash.contains(".foregroundStyle(SettingsTheme.ink2)"))
        #expect(trash.occurrences(of: ".iconButtonAffordance(") == 1)
    }

    /// A glyph standing alone beside text keeps the rest fill; the
    /// register is the owner-ruled sites (2026-09-25), so a new
    /// one is a ruling rather than a default.
    @Test("only the standalone glyphs rest on a fill")
    func restingRegister() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var hits: [String: Int] = [:]
        for url in try SourceScan.swiftSources(under: root) {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            let n = text.occurrences(of: "resting: true")
            if n > 0 { hits[url.lastPathComponent] = n }
        }
        #expect(
            hits == [
                "ProfilesSection+Rename.swift": 1,
                "ProfilesSection+ScreenSetups.swift": 1,
            ]
        )
    }

    /// The raised chip is the card's own recipe at chip size, and
    /// its one caller is the Desktops card's add-setup trigger.
    @Test("the add-setup trigger rides a raised chip")
    func addSetupIsRaised() throws {
        let rows = try source("Components/Common/SettingsRows.swift")
        let chip = body(of: "raisedChip", in: rows)
        #expect(chip.contains("SettingsTheme.card"))
        #expect(chip.contains("SettingsTheme.hairline"))
        #expect(chip.contains("SettingsTheme.planeRing"))
        let setups = try source(
            "Components/Profiles/DesktopsGroup+Setups.swift"
        )
        #expect(setups.occurrences(of: ".raisedChip()") == 1)
        #expect(!setups.contains(".settingsActionButton()"))
    }
}
