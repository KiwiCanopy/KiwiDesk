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
    /// The `AppRuleRow` family, DISCOVERED rather than listed —
    /// the row that draws the sentence, and any extension of it.
    ///
    /// A hand-list re-opens the hole file-scoping was adopted to
    /// close: the mutation that drove this scan out of the
    /// `sentence` property was a spacing helper declared beside
    /// it and composed in, and declaring that helper in a file
    /// the list does not name walks past it while every derived
    /// check still agrees. `AppRuleRow+Anything.swift` is where
    /// such a helper lands, and enumeration catches it.
    ///
    /// Scoped to `AppRuleRow`, NOT to `AppRule` — the wider
    /// prefix pulls in `AppRuleTitledEditor` and
    /// `AppRulesSection`, which are chrome rather than sentence
    /// and space their children correctly. Exempting them would
    /// trade this guard's one honest exemption for an allow-list
    /// that grows with every file in the area, and each entry is
    /// a place to wave a real gap through.
    ///
    /// Residue: a spacing helper declared OUTSIDE this family and
    /// composed into the row is invisible here. That is a smaller
    /// hole than the hand-list it replaces, not an absent one.
    private static func rowFiles() throws -> [URL] {
        let files = try SourceScan.swiftSources(
            under: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections"
                )
        ).filter {
            $0.lastPathComponent.hasPrefix("AppRuleRow")
        }
        // A floor, because an enumerator over a moved or renamed
        // directory yields [] and every check downstream would
        // then pass for having looked at nothing.
        #expect(files.count >= 2)
        return files
    }

    /// The one stack in these files that may space its children,
    /// and why — the single copy of who is exempt.
    ///
    /// `menuLabel` lays out a menu's VALUE and its chevron, both
    /// inside one control, so its gap can never fall between two
    /// segments of the frame. Every other stack here is either
    /// laying the sentence out or composed into something that
    /// does.
    private static let allowed = ["menuLabel": "spacing:4"]

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
        let files = try Self.rowFiles()
        var seen: [String] = []
        for url in files {
            let file = url.lastPathComponent
            let source = SourceScan.blankingCommentsAndLiterals(
                try String(contentsOf: url, encoding: .utf8)
            )
            var search = source.startIndex
            while let token = source.range(
                of: "HStack",
                range: search..<source.endIndex
            ) {
                search = token.upperBound
                let member = SourceScan.enclosingMember(
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
        // Assert the scan found something before trusting that it
        // found nothing wrong: the loop above is vacuously green
        // if no stack is matched at all, which is how a broken
        // needle passes for the wrong reason.
        //
        // NOT `scanned == rowFiles.count` — `scanned` is
        // incremented unconditionally inside the loop over
        // `rowFiles`, so the two sides are equal by construction
        // and the failing branch is unreachable (a missing file
        // throws first). guard-prover proved that shape dead
        // here; it is `2 * m > 2` wearing a non-vacuity check's
        // clothes. Every file must CONTRIBUTE a stack instead.
        #expect(
            seen.count >= files.count,
            Comment(
                rawValue:
                    "each row file lays something out "
                    + "horizontally; \(seen.count) stack(s) found "
                    + "across \(files.count) file(s) means "
                    + "one stopped contributing, or the needle "
                    + "stopped matching"
            )
        )
        // Every exempt member must actually have been seen — a
        // stale exemption is a hole with a reason attached — and
        // at least one NON-exempt stack must exist, or the only
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

    /// The sentence is still drawn by WALKING the frame, so the
    /// scan above is looking at a row that renders a translation
    /// rather than a fixed stack of labels.
    ///
    /// Scoped to the property's own body, and note the inversion
    /// against the test above: that one must be FILE-scoped,
    /// because a spacing helper can be declared outside the
    /// sentence and composed into it; this one must be
    /// BODY-scoped, because a `contains` over the file stays
    /// green on a DEAD `ForEach(frame.segments)` left anywhere
    /// while `sentence` stitches `control(at: 1)` /
    /// `Text(" opens in ")` / `control(at: 2)` — which is the
    /// exact regression turn 14a exists to prevent, and which
    /// the spacing test cannot see because a stitched stack
    /// still declares `spacing: 0`. guard-prover shipped it.
    ///
    /// The marker is `var sentence`, not the full declaration:
    /// matching `private var sentence: some View` would red on a
    /// reflow that `swift-format` could legitimately produce,
    /// and a formatting-only edit owes nothing (`tests.md`).
    @Test("the sentence is still emitted from the frame")
    func sentenceWalksTheFrame() throws {
        let source = SourceScan.blankingCommentsAndLiterals(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Sections/"
                            + "AppRuleRow.swift"
                    ),
                encoding: .utf8
            )
        )
        let marker = try #require(
            source.range(of: "var sentence"),
            "AppRuleRow must still draw the sentence itself"
        )
        let brace = try #require(
            source[marker.upperBound...].firstIndex(of: "{"),
            "the sentence must have a body"
        )
        var cursor = source.distance(
            from: source.startIndex,
            to: brace
        )
        let body = try #require(
            SourceScan.balanced(
                Array(source),
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "the sentence's body must be readable"
        )
        #expect(
            body.contains("ForEach(frame.segments)"),
            Comment(
                rawValue:
                    "the sentence must emit its pieces by walking "
                    + "the frame — a row that names positions in "
                    + "a fixed order cannot be reordered by any "
                    + "catalog, which is the whole point of "
                    + "SentenceFrame"
            )
        )
    }
}
