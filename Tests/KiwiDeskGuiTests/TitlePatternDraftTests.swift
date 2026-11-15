import Foundation
import Testing

@testable import KiwiDesk

/// A picked open title lands in the pattern field to trim before
/// Add, never in the stored patterns at once (#3340).
@Suite("Title pattern draft (#3340)")
struct TitlePatternDraftTests {
    @Test("a picked title opens the field holding it")
    func pickOpensTheField() {
        var draft = TitlePatternDraft()
        draft.start(with: "Amazon.de - Brave - Shop")
        #expect(draft.isOpen)
        #expect(draft.text == "Amazon.de - Brave - Shop")
    }

    @Test("a second pick replaces the text and counts as a pick")
    func secondPickReplaces() {
        var draft = TitlePatternDraft()
        draft.start(with: "First")
        draft.text = "Fir"
        let picks = draft.picks
        draft.start(with: "Second")
        #expect(draft.text == "Second")
        #expect(draft.picks == picks + 1)
    }

    @Test("Other (Specify)… opens the field empty")
    func specifyOpensEmpty() {
        var draft = TitlePatternDraft()
        draft.start(with: "Stale")
        draft.start()
        #expect(draft.isOpen)
        #expect(draft.text.isEmpty)
    }

    @Test("commit hands back the trimmed pattern and closes")
    func commitTrimsAndCloses() {
        var draft = TitlePatternDraft()
        draft.start(with: "  - Brave - Shop ")
        let pattern = draft.commit()
        #expect(pattern == "- Brave - Shop")
        #expect(!draft.isOpen)
        #expect(draft.text.isEmpty)
    }

    @Test("an empty field commits nothing and stays open")
    func emptyCommitStays() {
        var draft = TitlePatternDraft()
        draft.start(with: "   ")
        let pattern = draft.commit()
        #expect(pattern == nil)
        #expect(draft.isOpen)
    }

    @Test("Escape's cancel drops the text and closes")
    func cancelDrops() {
        var draft = TitlePatternDraft()
        draft.start(with: "Preferences")
        draft.cancel()
        #expect(!draft.isOpen)
        #expect(draft.text.isEmpty)
    }

    /// The wiring: a `Menu` cannot be clicked headless, so the
    /// open-title button is held on the add menu's source.
    @Test("an open title's button opens the draft, never adds")
    func openTitleOpensTheDraft() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "WindowTitleEditor.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let menu = try #require(
            SourceScan.declarationBody(
                after: "private var addWindowMenu",
                in: text
            ),
            "addWindowMenu is gone from WindowTitleEditor"
        )
        let squashed = menu.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashed.contains("Button(title){startDraft(with:title)}"),
            "a picked title no longer opens the pattern field"
        )
        #expect(
            !squashed.contains("addPattern("),
            "the add menu stores a pattern without the field again"
        )
        let start = try #require(
            SourceScan.declarationBody(
                after: "private func startDraft",
                in: text
            ),
            "startDraft is gone from WindowTitleEditor"
        )
        #expect(
            start.contains("draft.start(with: title)"),
            "a picked title opens an empty field"
        )
        let commit = try #require(
            SourceScan.declarationBody(
                after: "private func commitDraft",
                in: text
            ),
            "commitDraft is gone from WindowTitleEditor"
        )
        #expect(
            commit.contains("addPattern(pattern)"),
            "Return or Add no longer stores the pattern"
        )
        let field = try #require(
            SourceScan.declarationBody(
                after: "private var patternField",
                in: text
            ),
            "patternField is gone from WindowTitleEditor"
        )
        let squashedField = field.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashedField.contains(".onExitCommand{draft.cancel()"),
            "Escape no longer drops the pending pattern"
        )
        #expect(
            squashedField.contains(
                ".commitsOnSave($fieldFocused){commitDraft()}"
            ),
            "a Save or a blur drops a pending pattern again"
        )
    }
}
