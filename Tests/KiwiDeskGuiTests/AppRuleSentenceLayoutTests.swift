import Foundation
import Testing

@testable import KiwiDesk

/// The App Rules row is a localized SENTENCE, and its spacing
/// belongs to the translation rather than to the layout (#678
/// turn 14a).
///
/// A per-segment gap is invisible as a bug in English, whose
/// literals already carry their own spaces (`" opens in "`), so
/// the row merely reads a little wide. In ja and ko the literal
/// between two slots STARTS with a particle — `は`, `에` — that
/// must hug the noun before it, and a stack gap tears it off.
/// Those are the verb-final locales `SentenceFrame` exists for,
/// so a gap undoes the design in exactly the languages it was
/// built for. It shipped as `spacing: 6`; the localization round
/// caught it, no test did.
///
/// `SentenceFrameTests` owns the other half — that the splitter
/// hands back `" opens in "` with its spaces intact — so between
/// the two the sentence's spacing has exactly one owner.
@Suite("App Rules sentence layout")
struct AppRuleSentenceLayoutTests {
    /// The row's files. Pinned at two so a rename or a split
    /// cannot silently shrink the scan to nothing.
    private static let rowFiles = [
        "AppRuleRow.swift",
        "AppRuleRow+Facets.swift",
    ]

    /// The one stack in these files that may space its children,
    /// and why — the single copy of who is exempt.
    ///
    /// `menuLabel` lays out a menu's VALUE and its chevron, both
    /// inside one control, so its gap can never fall between two
    /// segments of the frame. Every other stack here is either
    /// laying the sentence out or composed into something that
    /// does.
    private static let allowed = ["menuLabel": "spacing:4"]

    /// Strips comments, then string literals — a literal is
    /// erased rather than removed so offsets stay usable.
    ///
    /// Without this a stack could be "found" inside a string:
    /// guard-prover satisfied the non-vacuity check with a
    /// `.accessibilityLabel("HStack(spacing: 0)")` while the row
    /// was laid out by a `VStack`.
    private func scrubbed(_ url: URL) throws -> String {
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        var out = ""
        var inString = false
        var escaped = false
        for character in source {
            if escaped {
                escaped = false
                continue
            }
            if character == "\\", inString {
                escaped = true
                continue
            }
            if character == "\"" {
                inString.toggle()
                out.append(character)
                continue
            }
            out.append(inString ? " " : character)
        }
        return out
    }

    /// The declaration a source offset sits in — the nearest
    /// preceding `var`/`func` name. That is what lets the exempt
    /// map key on a MEMBER rather than on a file, so a helper
    /// added beside `menuLabel` does not inherit its exemption.
    private func enclosingMember(
        of source: String,
        at offset: String.Index
    ) -> String {
        var name = "<file scope>"
        var cursor = source.startIndex
        while cursor < offset {
            let lineEnd =
                source[cursor...].firstIndex(of: "\n")
                ?? source.endIndex
            let line = source[cursor..<lineEnd]
            for keyword in ["var ", "func "] {
                guard let range = line.range(of: keyword) else {
                    continue
                }
                let rest = line[range.upperBound...]
                let identifier = rest.prefix {
                    $0.isLetter || $0.isNumber || $0 == "_"
                }
                if !identifier.isEmpty {
                    name = String(identifier)
                }
            }
            cursor =
                lineEnd < source.endIndex
                ? source.index(after: lineEnd) : source.endIndex
        }
        return name
    }

    /// Every horizontal stack in the row's files adds no spacing
    /// but the one exemption above.
    ///
    /// The unit is the FILES, not the `sentence` property, and
    /// that is the whole point of this cut. guard-prover walked
    /// through a body-scoped version twice: first with a stack
    /// nested inside `sentence`, then — after that was closed —
    /// with a `spaced { }` helper declared OUTSIDE `sentence`
    /// and composed into it, which restored the gap with the
    /// suite green. A stack that lays the sentence out does not
    /// have to be written inside the sentence.
    ///
    /// `HStack` is matched as a substring, so `LazyHStack` and
    /// `HStackLayout` are covered too.
    ///
    /// Residue, stated so a green here is not read as more than
    /// it is: any per-segment spacing that is NOT a stack
    /// argument is invisible to this — `.padding`, an inserted
    /// `Spacer`, a `.frame(width:)` — as is a `VStack`, which
    /// would break the row visibly rather than subtly. Only a
    /// render-level assertion could close that class, and this
    /// tree has no view-render harness.
    @Test("no stack in the row spaces the sentence")
    func rowStacksAddNoSpacing() throws {
        let directory = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections"
            )
        var scanned = 0
        var seen: [String] = []
        for file in Self.rowFiles {
            let source = try scrubbed(
                directory.appendingPathComponent(file)
            )
            scanned += 1
            var search = source.startIndex
            while let token = source.range(
                of: "HStack",
                range: search..<source.endIndex
            ) {
                search = token.upperBound
                let member = enclosingMember(
                    of: source,
                    at: token.lowerBound
                )
                seen.append(member)
                var at = source.distance(
                    from: source.startIndex,
                    to: token.upperBound
                )
                // A bare `HStack {` has no argument list, which
                // is SwiftUI's default spacing — the same bug by
                // omission, so a nil is a failure, never a stack
                // to skip.
                let arguments =
                    SourceScan.balanced(
                        Array(source),
                        from: &at,
                        open: "(",
                        close: ")"
                    ) ?? "<no argument list>"
                let spacing =
                    arguments
                    .split(separator: ",")
                    .map { $0.filter { !$0.isWhitespace } }
                    .filter { $0.hasPrefix("spacing:") }
                // Compared per ARGUMENT rather than as the whole
                // list: `HStack(alignment: .firstTextBaseline,
                // spacing: 0)` adds no gap and is a plausible
                // want for a row of text and menus, so pinning
                // the entire list would red it under a message
                // about spacing.
                #expect(
                    spacing == [
                        Self.allowed[member] ?? "spacing:0"
                    ],
                    Comment(
                        rawValue:
                            "\(file) ▸ \(member): a horizontal "
                            + "stack in the App Rules row must "
                            + "declare exactly spacing: 0 — the "
                            + "localized frame's own literals "
                            + "carry the spacing, and a gap "
                            + "detaches the ja/ko particle from "
                            + "the noun before it. If this stack "
                            + "cannot sit between two segments, "
                            + "add it to `allowed` with the "
                            + "reason."
                    )
                )
            }
        }
        #expect(scanned == Self.rowFiles.count)
        // Assert the scan found something before trusting that it
        // found nothing wrong: the loop above is vacuously green
        // if no stack is matched at all, which is how a broken
        // needle passes for the wrong reason.
        //
        // Both halves are derived rather than counted. Every
        // exempt member must actually have been seen — a stale
        // exemption is a hole with a reason attached — and at
        // least one NON-exempt stack must exist, or the only
        // thing this suite is watching is its own allow-list.
        for member in Self.allowed.keys {
            #expect(
                seen.contains(member),
                Comment(
                    rawValue:
                        "`\(member)` is exempt but was not found "
                        + "— drop it from `allowed`, or fix the "
                        + "scan that stopped seeing it"
                )
            )
        }
        #expect(
            seen.contains { Self.allowed[$0] == nil },
            "the scan matched only exempt stacks"
        )
    }

    /// The sentence is still drawn by walking the frame, so the
    /// scan above is looking at a row that renders a translation
    /// rather than a fixed stack of labels.
    @Test("the sentence is still emitted from the frame")
    func sentenceWalksTheFrame() throws {
        let source = try scrubbed(
            SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections/"
                        + "AppRuleRow.swift"
                )
        )
        #expect(source.contains("private var sentence: some View"))
        #expect(source.contains("ForEach(frame.segments)"))
    }
}
