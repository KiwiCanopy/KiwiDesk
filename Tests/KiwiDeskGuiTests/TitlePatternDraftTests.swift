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

    @Test("an empty start opens the field empty")
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

    /// The wiring (#3373): a listed open title fills the field,
    /// never adds, and the field adds only through the popover's
    /// own confirm, never through a Save's commit request.
    @Test("an open title fills the field, never adds")
    func openTitleFillsTheField() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "TitlePatternPopover.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let list = try #require(
            SourceScan.declarationBody(
                after: "private var titleList",
                in: text
            ),
            "titleList is gone from TitlePatternPopover"
        )
        let squashed = list.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashed.contains("Button{draft.start(with:title)}"),
            "a listed title no longer fills the pattern field"
        )
        #expect(
            !squashed.contains("onCommit("),
            "the list stores a pattern without the field again"
        )
        let commit = try #require(
            SourceScan.declarationBody(
                after: "private func commitDraft",
                in: text
            ),
            "commitDraft is gone from TitlePatternPopover"
        )
        #expect(
            commit.contains("onCommit(pattern)"),
            "Return or Add no longer stores the pattern"
        )
        let field = try #require(
            SourceScan.declarationBody(
                after: "private var patternField",
                in: text
            ),
            "patternField is gone from TitlePatternPopover"
        )
        let squashedField = field.split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(
            squashedField.contains(".onSubmit(commitDraft)"),
            "Return no longer adds the pattern"
        )
        #expect(
            !squashedField.contains(".commitsOnSave("),
            "a blur or a Save adds from the popover again"
        )
    }
}
