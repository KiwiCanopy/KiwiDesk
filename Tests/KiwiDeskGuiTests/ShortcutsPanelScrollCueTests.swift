import Foundation
import Testing

@testable import KiwiDesk

/// The ⌃⌥K reference panel cues its own fold in the footer,
/// and its titles are headings (#1292).
///
/// It cued the fold with `.scrollIndicators(.visible)` for one
/// commit. That was measured inert on device — macOS declines
/// it under overlay scrollers — so the clause guarding it went
/// with it rather than staying green over a no-op.
///
/// A source scan because there is nothing else: a SwiftUI
/// modifier leaves no trace a headless test can read.
///
/// `Sources/KiwiDesk/Shortcuts` has since joined
/// `ChromeScanRoots` (#1293), so `AnnouncedValuePinTests` now
/// counts this tree's `.isHeader` traits too — and the two do
/// not overlap the way the count suggests. That census is a
/// per-file TOTAL and reds if either header loses its trait or
/// a third appears; the clause here asks each named component's
/// own body, so it reds if the trait moves ONTO the wrong
/// component while the total holds. They fail apart, which is
/// what tests.md asks a second altitude to earn.
///
/// Every clause is anchored on the SUBJECT rather than on the
/// file. The scroll-view clauses walk each `ScrollView`'s own
/// modifier chain, and the header clauses each component's own
/// body — a first cut asserted two substrings occurred
/// anywhere in the file, and `guard-prover` moved the label
/// onto the footer, leaving the scroll view unnamed and the
/// whole suite green (2026-09-06).
@Suite("Shortcuts panel scroll cue (#1292)")
struct ShortcutsPanelScrollCueTests {
    private static func source(_ name: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
            .appendingPathComponent("Shortcuts")
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

    /// The modifier chain applied to one view, walked from the
    /// close of its trailing closure: whitespace, then `.name`
    /// with any balanced argument list, while the next
    /// non-space character is a dot.
    private static func modifierRun(
        _ characters: [Character],
        from cursor: inout Int
    ) -> String {
        var run = ""
        while true {
            var probe = cursor
            while probe < characters.count,
                characters[probe].isWhitespace
            {
                probe += 1
            }
            guard probe < characters.count,
                characters[probe] == "."
            else { return run }
            var end = probe + 1
            while end < characters.count,
                characters[end].isLetter
                    || characters[end].isNumber
            {
                end += 1
            }
            run += String(characters[probe..<end])
            cursor = end
            if let arguments = SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            ) {
                run += "(\(arguments))"
            }
            // A modifier may carry a trailing closure, and the
            // chain continues past it — `.overlay { … }` before
            // the modifier we want used to truncate the walk and
            // red on correct code. Its body is consumed and NOT
            // appended, which TRADES two things: a needle written
            // inside a closure is invisible to this walk, and
            // crossing a brace is fail-OPEN where the old stop
            // was fail-closed, so the `next is a dot` gate above
            // is what keeps the window narrow (`guard-prover`).
            _ = SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            )
        }
    }

    /// One entry per `ScrollView`, holding only the modifiers
    /// applied to THAT view — so a modifier drifting onto a
    /// sibling cannot answer for it.
    private static func scrollViewModifiers(
        in text: String
    ) -> [String] {
        let characters = Array(text)
        let marker = Array("ScrollView")
        var runs: [String] = []
        var index = 0
        while index + marker.count <= characters.count {
            // Bounded on the LEFT only: after the marker the walk
            // already requires `(` or `{`, which skips the
            // declaration and `ScrollViewReader`. Without this a
            // wrapper named `…ScrollView` matched at its call
            // site and redded on correct code. It TRADES a
            // project wrapper spelled with a prefix, which this
            // walk would stop seeing — bounded rather than
            // silent, since `panelScrollViews` then reds on an
            // empty result (`guard-prover`).
            let before =
                index > 0 ? characters[index - 1] : " "
            guard
                !(before.isLetter || before.isNumber
                    || before == "_"),
                Array(characters[index..<(index + marker.count)])
                    == marker
            else {
                index += 1
                continue
            }
            var cursor = index + marker.count
            _ = SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            )
            guard
                SourceScan.balanced(
                    characters,
                    from: &cursor,
                    open: "{",
                    close: "}"
                ) != nil
            else {
                index += 1
                continue
            }
            runs.append(modifierRun(characters, from: &cursor))
            index = cursor
        }
        return runs
    }

    private static func panelScrollViews() throws -> [String] {
        let text = try source("ShortcutsPanelView.swift")
        let runs = scrollViewModifiers(in: text)
        #expect(!runs.isEmpty, "no ScrollView found to guard")
        return runs
    }

    /// VoiceOver lands on the scroll view before interacting
    /// into it, so it is named rather than announced as a bare
    /// "scroll area" — asserted on that view's own chain, so a
    /// label on a sibling cannot answer for it.
    @Test("every panel scroll view is named")
    func everyPanelScrollViewIsNamed() throws {
        for run in try Self.panelScrollViews() {
            #expect(
                run.contains(".accessibilityLabel"),
                "a panel ScrollView carries no label"
            )
            #expect(
                run.contains("shortcuts.panel.ax_label"),
                "the label is not the panel's own key"
            )
        }
    }

    /// The fold's verdict is arithmetic and lives in ONE place,
    /// so it is asserted directly at the boundary rather than
    /// scanned for. Equal is NOT overflow: the content is
    /// clamped to the ceiling, so a panel exactly at it lost
    /// nothing and must not claim there is more.
    @Test("the overflow verdict is exact at the boundary")
    @MainActor
    func theOverflowVerdictIsExactAtTheBoundary() {
        #expect(
            !ShortcutsPanelController.overflows(
                fitting: 720,
                ceiling: 720
            )
        )
        #expect(
            ShortcutsPanelController.overflows(
                fitting: 720.5,
                ceiling: 720
            )
        )
        #expect(
            !ShortcutsPanelController.overflows(
                fitting: 719.5,
                ceiling: 720
            )
        )
    }

    /// The cue is MOUNTED, gated, and draws its own string.
    ///
    /// Keyed on the footer's own body for the mount — a private
    /// computed property nothing renders compiles silently, and
    /// the band one suite over went missing from the screen with
    /// every builder expectation green
    /// (`ShortcutsInactiveBandTests` ▸ `theViewDrawsTheBand`).
    /// The GATE is asked of the file rather than of `scrollCue`:
    /// moving the `if` up into the footer honours the invariant
    /// exactly, and pinning one spelling billed a false red for
    /// it (`guard-prover`, 2026-09-07).
    @Test("the cue is mounted, gated, and drawn")
    func theCueIsMountedGatedAndDrawn() throws {
        let text = try Self.source("ShortcutsPanelView.swift")
        let footer = try #require(
            SourceScan.declarationBody(
                after: "private var footer",
                in: text
            ),
            "footer not found"
        )
        #expect(
            footer.contains("scrollCue"),
            "the footer does not mount the cue"
        )
        #expect(
            text.contains("if overflows"),
            "the cue is drawn ungated"
        )
        #expect(
            text.contains("shortcuts.panel.scroll_hint"),
            "the cue does not draw its own string"
        )
    }

    /// The verdict REACHES the view. Proven arithmetic whose
    /// caller ignores it is the #1292 defect back verbatim:
    /// `resize` returning a constant, or the re-root deleted
    /// outright, left every other clause here green
    /// (`guard-prover`, 2026-09-07). Counted on BOTH sides, so
    /// deleting the wiring reds as loudly as duplicating it.
    @Test("the verdict reaches the view")
    func theVerdictReachesTheView() throws {
        let text = try Self.source(
            "ShortcutsPanelController.swift"
        )
        for needle in [
            "Self.overflows(",
            "if resize(panel)",
            "view(overflows: true)",
            "view(overflows: false)",
        ] {
            #expect(
                text.occurrences(of: needle) == 1,
                "\(needle): expected exactly one site"
            )
        }
    }

    /// Both title components carry the heading trait, asked of
    /// each one's own body — the headings rotor is the only way
    /// through forty rows without a mouse.
    @Test("both panel title components are headings")
    func bothTitleComponentsAreHeadings() throws {
        let text = try Self.source("ShortcutsBands.swift")
        for component in [
            "ShortcutsBandHeader", "ShortcutSubgroupView",
        ] {
            let body = try #require(
                SourceScan.declarationBody(
                    after: "struct \(component)",
                    in: text
                ),
                "\(component) not found"
            )
            #expect(
                body.contains(
                    ".accessibilityAddTraits(.isHeader)"
                ),
                "\(component): title is not a heading"
            )
        }
    }
}
