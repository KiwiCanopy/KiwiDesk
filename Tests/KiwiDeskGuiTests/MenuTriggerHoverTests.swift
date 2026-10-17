import Foundation
import Testing

/// A borderless menu trigger lifts under the pointer like every
/// other click target KiwiDesk draws, while the menu it opens
/// stays native (owner ruling 2026-10-17). The lift goes on the
/// control, outside the `Menu`, because AppKit flattens a
/// borderless menu's label and drops anything drawn inside it.
///
/// Off the main actor: pure source reads over `ChromeScanRoots`.
@Suite("Menu trigger hover")
struct MenuTriggerHoverTests {
    /// The lifts a borderless trigger may take: the text tier, or
    /// the glyph tier (directly or through its affordance).
    private static let lifts = [
        ".menuTriggerHover()", ".iconHoverChip(",
        ".iconButtonAffordance(",
    ]

    private func sources() throws -> [(String, String)] {
        try ChromeScanRoots.sources(from: #filePath).map { url in
            (
                url.lastPathComponent,
                SourceScan.stripComments(
                    try String(contentsOf: url, encoding: .utf8)
                )
            )
        }
    }

    /// The modifier chain that follows `index`: every later line
    /// that opens with `.`, plus the lines a modifier's own
    /// parentheses span. Blank lines (a stripped comment) are
    /// skipped; anything else ends the chain.
    private func chain(
        in source: String,
        after index: String.Index
    ) -> String {
        var lines = source[index...].split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .dropFirst()
        .makeIterator()
        var depth = 0
        var result = ""
        while let line = lines.next() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if depth == 0 {
                if trimmed.isEmpty { continue }
                guard trimmed.hasPrefix(".") else { break }
            }
            result += trimmed + "\n"
            depth += trimmed.filter { $0 == "(" }.count
            depth -= trimmed.filter { $0 == ")" }.count
        }
        return result
    }

    /// Every `.menuStyle(.borderlessButton)` carries a lift in its
    /// own chain — a per-occurrence check, so a lift on a
    /// neighbouring control cannot stand in for a missing one.
    @Test("every borderless menu trigger lifts")
    func borderlessMenusLift() throws {
        var seen = 0
        for (name, source) in try sources() {
            var cursor = source.startIndex
            while let hit = source.range(
                of: ".menuStyle(.borderlessButton)",
                range: cursor..<source.endIndex
            ) {
                cursor = hit.upperBound
                seen += 1
                let rest = chain(in: source, after: hit.lowerBound)
                #expect(
                    Self.lifts.contains { rest.contains($0) },
                    Comment(
                        rawValue:
                            "\(name): a borderless menu with no "
                            + "hover lift in its chain"
                    )
                )
            }
        }
        // A scan that found no menus passed having looked at
        // nothing.
        #expect(seen > 5)
    }

    /// The popover triggers drawn with the App Rules menu label —
    /// the "Applies to" controls — lift the same way: one lift per
    /// label, in every file outside the label's own declaration.
    @Test("every App Rules menu label's control lifts")
    func menuLabelControlsLift() throws {
        var seen = 0
        for (name, source) in try sources() {
            let labels = source.occurrences(of: "AppRuleMenuLabel(text:")
            guard labels > 0 else { continue }
            seen += labels
            #expect(
                source.occurrences(of: ".menuTriggerHover()") == labels,
                Comment(rawValue: name)
            )
        }
        #expect(seen > 5)
    }

    /// The text tier rests at nothing and lifts on a chip token,
    /// edgeless like the glyph tier: no passive control shares its
    /// shape (#2047). Which token is a tuning.
    @Test("the trigger lift rests at nothing and lifts on a token")
    func triggerTierShape() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "SettingsRows.swift"
            )
        let rows = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let tier = try #require(
            SourceScan.declarationBody(
                after: "func menuTriggerHover()",
                in: rows
            )
        )
        let squashed = tier.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashed.contains(
                "hoverHighlight(rest:.clear,hover:SettingsTheme."
            )
        )
        #expect(squashed.contains(",edge:nil,"))
        #expect(!tier.contains(".opacity("))
    }
}
