import Foundation
import Testing

@testable import KiwiDesk

/// The App Rules rows are wired to what #1608 split them for.
///
/// Nothing headless can click a `Menu`, so what a row CAN write
/// is held on its source. Every clause is scoped to a file or a
/// brace-balanced body, never the whole tree, because a
/// file-wide needle is satisfied by a neighbour
/// (`AppRulesAddOnSelectTests`, 2026-09-22).
@Suite("App Rules list wiring (#1608)")
struct AppRuleListsWiringTests {
    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    private func raw(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/" + file
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // A read that came back empty fails-open every negative
        // clause below.
        #expect(text.count > 400, "\(file) read empty")
        return text
    }

    private func source(_ file: String) throws -> String {
        Self.squashed(try raw(file))
    }

    /// The brace-balanced body after `signature` in `file`.
    private func body(
        of signature: String,
        in file: String
    ) throws -> String {
        let text = try raw(file)
        let offset = try #require(
            text.range(of: signature),
            "\(signature) is gone from \(file)"
        )
        var cursor = text.distance(
            from: text.startIndex,
            to: offset.upperBound
        )
        let found = try #require(
            SourceScan.balanced(
                Array(text),
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "\(signature) has no balanced body to read"
        )
        return Self.squashed(found)
    }

    /// The scope fix itself: a title pattern's editor hangs under
    /// the FLOAT row, and the Space row mounts none.
    @Test("the pattern editor lives in the Float row alone")
    func patternEditorScopesToFloat() throws {
        #expect(
            try source("AppRuleFloatRow.swift")
                .contains("AppRuleTitledEditor("),
            "the Float row no longer mounts the pattern editor"
        )
        #expect(
            !(try source("AppRuleSpaceRow.swift"))
                .contains("AppRuleTitledEditor"),
            Comment(
                rawValue:
                    "the Space row draws a title pattern again — "
                    + "the Space is title-blind, and a pattern "
                    + "under it reads as scoping it (#1608)"
            )
        )
    }

    /// A rule must say something, by construction: the Space
    /// menu offers only Spaces, and the one way out of a list is
    /// its trash — which the section, not the row, performs. So
    /// the row's ONE write to the store is the pick of a Space;
    /// counted, so a `= .none` or a `removeValue` reds as surely
    /// as a `= nil`.
    @Test("the Space row never writes an absent Space")
    func spaceRowWritesNoAbsence() throws {
        // Comparisons blanked first: `appRules[app] == base` is a
        // read, and would count as a write.
        let row = try source("AppRuleSpaceRow.swift")
            .replacingOccurrences(of: "==", with: "≡")
        let writes = row.components(separatedBy: "appRules[app]=")
        let picks = row.components(
            separatedBy: "appRules[app]=space"
        )
        #expect(
            writes.count == 2 && picks.count == 2
                && !row.contains("removeValue")
                && !row.contains("config.appRules="),
            Comment(
                rawValue:
                    "the Space row writes its store other than by "
                    + "picking a Space — a row left saying nothing "
                    + "is the state #1022 and #1608 forbid"
            )
        )
    }

    /// The deletion focus lands on a control that can HOLD it
    /// (#816): the Space menu, or the trash while the menu is
    /// greyed for want of a Space.
    @Test("the Space row's focus falls back to the trash")
    func spaceFocusFallsBack() throws {
        let file = "AppRuleSpaceRow.swift"
        #expect(
            try body(
                of: "private func focusValue(menu: Bool) -> String",
                in: file
            ).contains(
                Self.squashed(
                    "menu == gates.hasSpaces ? app : Self.neverFocused"
                )
            ),
            "the focus no longer follows the Space menu's grey"
        )
        #expect(
            try source(file).contains(
                Self.squashed(
                    ".focused($returningRow, "
                        + "equals: focusValue(menu: false))"
                )
            ),
            "the trash is no longer the fallback focus destination"
        )
    }

    /// A row composing its first pattern holds no stored rule, and
    /// its trash is the way back out — so it stays enabled.
    @Test("a composing Float row keeps its trash")
    func composingRowKeepsItsTrash() throws {
        #expect(
            try source("AppRuleFloatRow.swift").contains(
                Self.squashed(
                    ".disabled(scope == .never && !editingTitles)"
                )
            ),
            Comment(
                rawValue:
                    "the Float trash no longer stays live while "
                    + "a first pattern is composed — the user "
                    + "cannot back out of the editor (#1608)"
            )
        )
    }

    /// The titled choice must NOT clear the float rule: a bare
    /// rule may be the row's only stored rule, and clearing it
    /// dropped the row mid-composition (#1022).
    @Test("opening the pattern editor clears no float rule")
    func openTitlesKeepsTheRule() throws {
        let open = try body(
            of: "private func openTitles()",
            in: "AppRuleFloatRow.swift"
        )
        #expect(
            !open.contains("floatRules"),
            Comment(
                rawValue:
                    "openTitles writes the float rules again — a "
                    + "float-only row vanishes from the list "
                    + "mid-composition (#1022)"
            )
        )
        #expect(
            try source("AppRuleFloatRow.swift").contains(
                Self.squashed("Button(titledLabel) { openTitles() }")
            )
        )
    }

    /// The composing row stays LISTED while its editor is open,
    /// and the slot is released by a deletion and by a reload.
    @Test("the composing row is unioned into the Float list")
    func composingRowSurvivesInTheList() throws {
        let file = "AppRulesSection+Lists.swift"
        #expect(
            try body(of: "var floatApps: [String]", in: file)
                .contains(
                    Self.squashed(
                        "if let composing = composingTitles { "
                            + "set.insert(composing) }"
                    )
                ),
            Comment(
                rawValue:
                    "`floatApps` no longer keeps the row under "
                    + "composition — a titled rule has nothing "
                    + "stored until its first pattern lands (#1022)"
            )
        )
        #expect(
            try body(of: "private func deleteFloat(_ app: String)", in: file)
                .contains(
                    Self.squashed(
                        "if composingTitles == app "
                            + "{ composingTitles = nil }"
                    )
                )
        )
        #expect(
            try source("AppRulesSection.swift").contains(
                Self.squashed(
                    ".onChange(of: model.cleanConfig) "
                        + "{ composingTitles = nil }"
                )
            )
        )
    }

    /// Each list reads its own store. `AppRuleListsTests` holds
    /// the answers; this holds that the pickers exclude by the
    /// list they add to, or a pinned app could never be floated.
    @Test("each picker excludes only its own list")
    func pickersExcludeTheirOwnList() throws {
        let file = "AppRulesSection+Lists.swift"
        for (card, list) in [
            ("spaceList", "spaceApps"), ("floatList", "floatApps"),
        ] {
            #expect(
                try body(of: "var \(card): some View", in: file)
                    .contains("exclude:Set(\(list))"),
                Comment(
                    rawValue:
                        "\(card)'s picker no longer excludes "
                        + "\(list) — excluding the OTHER list "
                        + "stops an app ever carrying both rules"
                )
            )
        }
    }
}
