import Foundation
import Testing

@testable import KiwiDesk

/// The App Rules section draws both lists and wires each to its
/// own state (#1608).
///
/// `AppRuleListsTests` holds what each list DERIVES; nothing
/// headless can set the section's `@State` or `@FocusState`, so
/// what it DRAWS and which state a card hands its rows is held on
/// source — each clause read from one balanced body, since a card
/// handed the other card's binding still satisfies a file-wide
/// needle (guard-prover, 2026-09-23).
@Suite("App Rules section wiring (#1608)")
struct AppRulesSectionWiringTests {
    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    /// The brace-balanced body after `signature` in `file`.
    private func body(
        of signature: String,
        in file: String
    ) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/" + file
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
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

    private static let lists = "AppRulesSection+Lists.swift"

    private func card(_ name: String) throws -> String {
        try body(of: "var \(name): some View", in: Self.lists)
    }

    /// Both cards are drawn — the census declares two containers,
    /// and nothing else reads the render.
    @Test("the section draws both cards, each its own control")
    func bothCardsDrawn() throws {
        let section = try body(
            of: "var body: some View",
            in: "AppRulesSection.swift"
        )
        #expect(
            section.contains("spaceList")
                && section.contains("floatList"),
            "the section no longer draws both App Rules cards"
        )
        for name in ["spaceList", "floatList"] {
            #expect(
                try card(name).contains(
                    "SettingsCatalog.appRules.\(name)"
                ),
                "\(name) is not mounted on its catalog control"
            )
        }
    }

    /// Each card hands its rows its OWN focus binding and its
    /// picker excludes by its OWN list — anchored through the
    /// next argument, so a union with the other list reds too.
    @Test("each card is wired to its own state")
    func cardsTakeTheirOwnState() throws {
        let space = try card("spaceList")
        let float = try card("floatList")
        #expect(
            space.contains("returningRow:$returningSpaceRow")
                && float.contains("returningRow:$returningFloatRow"),
            "a card hands its rows the other list's focus binding"
        )
        #expect(
            space.contains(
                "exclude:Set(spaceApps),onCommit:addWithSpace"
            )
                && float.contains(
                    "exclude:Set(floatApps),onCommit:addFloating"
                ),
            Comment(
                rawValue:
                    "a picker no longer excludes exactly its own "
                    + "list — excluding the other one stops an app "
                    + "ever carrying both rules"
            )
        )
        // The area-wide empty note, read from both lists.
        #expect(
            space.contains(Self.squashed("if hasNoRules { emptyNote }")),
            "the empty note no longer asks whether BOTH lists are empty"
        )
    }

    /// The composing row stays LISTED while its editor is open,
    /// and a deletion releases the slot BEFORE it names the focus —
    /// in the other order `floatApps` still lists the row, and
    /// focus stays on a row that is about to vanish.
    @Test("the composing row is listed and released in order")
    func composingSlotLifecycle() throws {
        #expect(
            try body(of: "var floatApps: [String]", in: Self.lists)
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
            try body(
                of:
                    "private func deleteFloat(_ app: String, "
                    + "_ removal: RuleRemoval)",
                in: Self.lists
            ).contains(
                Self.squashed(
                    "if composingTitles == app "
                        + "{ composingTitles = nil } "
                        + "returningFloatRow = "
                        + "floatApps.contains(app) ? app : neighbour"
                )
            ),
            "deleteFloat no longer releases the slot before focusing"
        )
        #expect(
            try body(of: "var body: some View", in: "AppRulesSection.swift")
                .contains(
                    Self.squashed(
                        ".onChange(of: model.cleanConfig) "
                            + "{ composingTitles = nil }"
                    )
                ),
            "a reload no longer releases the composing slot"
        )
    }
}
