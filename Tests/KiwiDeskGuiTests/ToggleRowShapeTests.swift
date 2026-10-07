import Foundation
import Testing

/// An on/off setting is a `ToggleRow`, never a `Toggle` dropped
/// into `DropdownRow` — whose menu-picker styling drew General's
/// checkboxes as faint squares and truncated their labels
/// (#2032) — and `ToggleRow`'s `disabled:` is the one grey its
/// gated callers have.
@Suite("Toggle rows")
struct ToggleRowShapeTests {
    private var root: URL { SourceScan.repoRoot(from: #filePath) }

    /// `disabled:` greys the checkbox and nothing else: chained on
    /// the `Toggle` and ended before the help branch, so the `?`
    /// stays live under a grey (#527). The three gated General
    /// rows hand their reason here, so a dropped `.disabled`
    /// would leave each of them editable.
    @Test("the disabled argument greys the checkbox, not the help")
    func disabledGreysTheToggleAlone() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Common/"
                        + "SettingsRows.swift"
                ),
                encoding: .utf8
            )
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "struct ToggleRow:",
                in: source
            )
        )
        let squashed = body.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashed.contains(
                "Toggle(isOn:$isOn){Text(label)}.fixedSize()"
                    + ".disabled(disabled)iflethelp{HelpButton("
            )
        )
        #expect(squashed.occurrences(of: ".disabled(") == 1)
    }

    /// No `Toggle(` in a `DropdownRow`'s trailing closure, across
    /// the whole GUI tree.
    @Test("no toggle sits inside a dropdown row")
    func noToggleInADropdownRow() throws {
        let files = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
        var rows = 0
        var offenders: [String] = []
        for file in files {
            let text = Array(
                SourceScan.blankingCommentsAndLiterals(
                    try String(contentsOf: file, encoding: .utf8)
                )
            )
            for start in Self.starts(of: "DropdownRow(", in: text) {
                var cursor = start + "DropdownRow".count
                guard
                    SourceScan.balanced(
                        text,
                        from: &cursor,
                        open: "(",
                        close: ")"
                    ) != nil,
                    let closure = SourceScan.balanced(
                        text,
                        from: &cursor,
                        open: "{",
                        close: "}"
                    )
                else { continue }
                rows += 1
                if closure.contains("Toggle(") {
                    offenders.append(file.lastPathComponent)
                }
            }
        }
        // The scan found its input before asserting about it.
        #expect(rows >= 2)
        #expect(
            offenders.isEmpty,
            Comment(
                rawValue:
                    "a Toggle inside DropdownRow in \(offenders) — "
                    + "an on/off setting takes ToggleRow (#2032)"
            )
        )
    }

    private static func starts(
        of needle: String,
        in text: [Character]
    ) -> [Int] {
        let pattern = Array(needle)
        guard text.count >= pattern.count else { return [] }
        return (0...(text.count - pattern.count)).filter { i in
            text[i..<(i + pattern.count)].elementsEqual(pattern)
                && (i == 0 || !Self.isIdentifier(text[i - 1]))
        }
    }

    private static func isIdentifier(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }
}
