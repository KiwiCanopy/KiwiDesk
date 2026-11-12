import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The key panel's Shortcuts side (#2246) says it scrolls by
/// fading its cut edges, as every KiwiHub list does (#3249,
/// replacing #1292's worded cue); the key sequence panel, which
/// hosts the same sheet, keeps its own fade and its Scroll hint
/// (#3175). Its section titles are headings (#1292).
///
/// A source scan because there is nothing else: a SwiftUI
/// modifier leaves no trace a headless test can read. Comments
/// are stripped so one quoting a modifier cannot stand in for the
/// call site (#1069), and every clause is asked of its subject's
/// own body rather than the file (`guard-prover`, 2026-09-06).
@Suite("Shortcuts panel scroll (#1292, #3249)")
struct ShortcutsPanelScrollTests {
    private static func source(
        _ name: String,
        in directory: String = "Jump"
    ) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
            .appendingPathComponent(directory)
            .appendingPathComponent(name)
        let text = try String(contentsOf: url, encoding: .utf8)
        // Comments are stripped so one quoting a modifier cannot
        // stand in for the call site (#1069). Trimmed before the
        // emptiness check: a comment-only file strips to
        // whitespace, which is not `.isEmpty` (`guard-prover`).
        let stripped = SourceScan.stripComments(text)
        #expect(
            !stripped.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            "\(name) read empty"
        )
        return stripped
    }

    /// VoiceOver lands on the scroll view before interacting
    /// into it, so it is named rather than announced as a bare
    /// "scroll area" — on the chain of the one view either scroll
    /// is drawn as.
    @Test("the sheet's scroll view is named")
    func theScrollViewIsNamed() throws {
        let text = try Self.source("JumpShortcutsView.swift")
        let body = try #require(
            SourceScan.declarationBody(after: "var body: some View", in: text)
        )
        #expect(body.contains("scrollView"))
        #expect(
            body.contains(".accessibilityLabel(JumpScope.shortcuts.panelName)")
        )
    }

    /// KiwiHub's sheet fades through `FadingScroll`; the key
    /// sequence panel's turns that off and keeps its own fade, so
    /// no sheet fades twice.
    @Test("KiwiHub's sheet fades, and only once")
    func theSheetFades() throws {
        let text = try Self.source("JumpShortcutsView.swift")
        let scroll = try #require(
            SourceScan.declarationBody(
                after: "private var scrollView",
                in: text
            )
        )
        #expect(scroll.contains("if fades {"))
        #expect(
            scroll.contains(
                "FadingScroll(inset: verticalInset) { sheetContent }"
            )
        )
        // Each host says whether the sheet fades.
        #expect(text.contains("let fades: Bool"))
        let panel = try Self.source("JumpPanelView.swift")
        #expect(panel.occurrences(of: "fades: true") == 1)
        let hint = try Self.source(
            "KeySequenceHintView.swift",
            in: "Shortcuts"
        )
        #expect(hint.occurrences(of: "fades: false") == 1)
        #expect(hint.occurrences(of: ".moreBelowFade()") == 1)
        // No scroll line in KiwiHub's footer, under any name: the
        // footer files draw no scroll key at all.
        for name in [
            "JumpPanelView+Footer.swift", "JumpPanelChrome.swift",
            "JumpFooter+Windows.swift",
        ] {
            let footer = try Self.source(name)
            #expect(footer.occurrences(of: "scroll") == 0, "\(name)")
        }
    }

    /// The fold's verdict is arithmetic and lives in ONE place,
    /// so it is asserted directly at the boundary rather than
    /// scanned for. Equal is NOT overflow: the sheet is clamped
    /// to its cap, so a sheet exactly at it lost nothing and must
    /// not claim there is more.
    @Test("the overflow verdict is exact at the boundary")
    @MainActor
    func theOverflowVerdictIsExactAtTheBoundary() {
        #expect(!JumpShortcutsView.overflows(content: 520, cap: 520))
        #expect(JumpShortcutsView.overflows(content: 520.5, cap: 520))
        #expect(!JumpShortcutsView.overflows(content: 519.5, cap: 520))
    }

    /// The verdict READS the measured sheet against its cap.
    /// Proven arithmetic whose inputs are constants is the #1292
    /// defect back verbatim (`guard-prover`, 2026-09-07): the sheet
    /// reports its height, the key sequence panel reads it, and its
    /// Scroll hint asks the verdict of it.
    @Test("the verdict reaches the key sequence panel")
    func theVerdictReachesTheView() throws {
        let sheet = try Self.source("JumpShortcutsView.swift")
        let hint = try Self.source(
            "KeySequenceHintView.swift",
            in: "Shortcuts"
        )
        for (text, needle) in [
            (sheet, "key: SheetHeightKey.self"),
            (sheet, ".frame(maxHeight: maxHeight)"),
            (
                hint,
                "onPreferenceChange(SheetHeightKey.self) { sheetHeight = $0 }"
            ),
            // The cap the sheet is drawn under is the one it is judged
            // against.
            (hint, "maxHeight: endKeyCap,"),
            (
                hint,
                "JumpShortcutsView.overflows(content: sheetHeight, "
                    + "cap: endKeyCap)"
            ),
        ] {
            #expect(
                text.occurrences(of: needle) == 1,
                "\(needle): expected exactly one site"
            )
        }
        // The Scroll hint is drawn only on the verdict.
        let footer = try #require(
            SourceScan.declarationBody(after: "private var footer", in: hint)
        )
        .filter { !$0.isWhitespace }
        #expect(
            footer.contains(
                "ifoverflows{Text(L(\"key_sequence.hint.scroll\""
            )
        )
        #expect(footer.occurrences(of: "key_sequence.hint.scroll") == 1)
    }

    /// Each section title carries the heading trait, asked of
    /// the section's own body — the headings rotor is the only way
    /// through forty rows without a mouse.
    @Test("every section title is a heading")
    func everySectionTitleIsAHeading() throws {
        let text = try Self.source(
            "ShortcutsSheetView.swift",
            in: "Shortcuts"
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "private func sectionView",
                in: text
            ),
            "sectionView not found"
        )
        #expect(
            body.contains(".accessibilityAddTraits(.isHeader)"),
            "a section title is not a heading"
        )
    }
}
