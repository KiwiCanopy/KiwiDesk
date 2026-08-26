import Foundation
import Testing

/// What a drawer header is DRAWN at (#1021), as against
/// `SettingsDisclosureHeaderTests`, which owns what it is: a
/// full-row button, an accessory beside it, its state in words.
///
/// Split because the size clauses took that suite past the
/// 350-line ceiling, and because they watch a different thing —
/// these red when the header's tier goes back to being a
/// call-site decision, when the indicator pins a size of its
/// own instead of inheriting the header's, or when the summary
/// beside the title stops routing through the one slot.
@Suite("Settings drawer header size")
struct SettingsDisclosureSizeTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var settingsRoot: URL {
        root.appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Source with comments removed and whitespace squashed, so
    /// a needle cannot be broken by a reflow — and cannot be
    /// SATISFIED by the prose arguing for the very mechanism it
    /// watches. The hand-rolled strip this carried returned the
    /// comment for any line beginning at column 0 with `//`, so
    /// every type-level docstring leaked in as scannable source
    /// (code review, 2026-08-26). `SourceScan.stripComments` is
    /// the ratified walker and the sibling suite's; a second,
    /// weaker copy beside it is the exact drift `tests.md`
    /// ratifies that family against.
    private func squashed(_ repoRelative: String) throws -> String {
        let raw = try String(
            contentsOf: root.appendingPathComponent(repoRelative),
            encoding: .utf8
        )
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    private static let styleFile =
        "Sources/KiwiDesk/Settings/Components/Common/"
        + "SettingsDisclosureStyle.swift"

    private static let wrapperFile =
        "Sources/KiwiDesk/Settings/Components/Common/"
        + "SettingsDisclosure.swift"

    @Test("the indicator is sized by the header it marks")
    func chevronInheritsTheHeaderFont() throws {
        let style = try squashed(Self.styleFile)
        // PROPORTIONAL, not a size of its own (#1021). The
        // chevron takes no `.font`, so it inherits the header's
        // — which is what #956 claimed and did not do: it
        // replaced the native triangle for being drawn at the
        // system's small size, then pinned the replacement at
        // `.footnote`, the smallest step on the ramp.
        //
        // A SCALE STEP is the other half, and the one that
        // shipped: `.imageScale(.large)` on top of the
        // inheritance drew the indicator larger than the title
        // it marks, which is the heavy header the owner read
        // back (2026-08-26). Weight is the only step it takes.
        //
        // The run is BRACE-BALANCED over the whole function.
        // Both cheaper bounds were proven fail-OPEN: an
        // `.accessibilityHidden(true)` anchor ends the run above
        // a scale step appended below it, and "the first `}` is
        // the function's" is a state claim one `.background { }`
        // falsifies — with that in the chain the suite passed
        // green with the regression live (guard-prover,
        // 2026-08-26).
        let chevronRun = try body(
            of: "privatefuncchevron(expanded:Bool)->someView",
            in: style
        )
        #expect(
            !chevronRun.contains(".font("),
            Comment(
                rawValue:
                    "the chevron pins a size again; it must "
                    + "inherit the header's — \(chevronRun)"
            )
        )
        // Non-vacuity, on the run's IDENTITY rather than on a
        // weight. `.fontWeight(.bold)` stood here and pinned an
        // aesthetic: nobody changes a chevron's weight by
        // accident, and changing it on purpose only made the
        // author edit a test to agree with themselves — while
        // billing a `guard-prover` run for the privilege.
        #expect(chevronRun.contains("chevron.right"))
        #expect(
            !chevronRun.contains(".imageScale("),
            Comment(
                rawValue:
                    "the chevron takes a scale step again; it "
                    + "must be the header's own size — "
                    + "\(chevronRun)"
            )
        )
    }

    /// The body of a declaration, brace-balanced through
    /// `SourceScan` rather than by a second walker beside it.
    private func body(
        of declaration: String,
        in squashed: String
    ) throws -> String {
        let characters = Array(squashed)
        let head = try #require(
            squashed.range(of: declaration),
            "`\(declaration)` is gone"
        )
        var cursor = squashed.distance(
            from: squashed.startIndex,
            to: head.upperBound
        )
        return try #require(
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "`\(declaration)` does not close"
        )
    }

    /// How many fonts a run applies. The count IS the
    /// invariant behind "one tier, one home": SwiftUI draws the
    /// last `.font` in a chain, so a positive needle for the
    /// shared tier stays green beside a literal appended after
    /// it (guard-prover, 2026-08-26).
    private func fonts(in run: String) -> Int {
        run.components(separatedBy: ".font(").count - 1
    }

    /// The modifier run of one expression, so a needle cannot be
    /// satisfied by one belonging to another view in the file.
    /// Only for POSITIVE clauses: it stops at the first `}`, so
    /// a negative clause reading it would go green whenever a
    /// trailing-closure modifier shortened the run.
    private func run(
        in squashed: String,
        from start: String,
        to end: String
    ) throws -> String {
        let lower = try #require(squashed.range(of: start))
        let rest = lower.upperBound..<squashed.endIndex
        let upper = try #require(
            squashed.range(of: end, range: rest)
        )
        return String(squashed[lower.lowerBound..<upper.upperBound])
    }

    @Test("the label tier is not a call-site decision")
    func chromeCarriesNoFont() throws {
        // The owner's complaint, at its mechanism (#1021): the
        // `Chrome` case used to carry a `font:` payload, so each
        // call site picked its own header tier and seven of the
        // fifteen drawers ended up drawn SMALLER than the rows
        // they head. A payload here is that drift's only door.
        let file = try squashed(Self.wrapperFile)
        #expect(file.contains("caseinline"))
        #expect(
            !file.contains("caseinline(font:"),
            "the chrome carries a font payload again"
        )
        #expect(
            !file.contains("labelFont"),
            "the per-chrome label font is back"
        )
        // Scoped to the LABEL's own BRACE-BALANCED run. Read
        // against the whole file this passed green when the
        // `.font` was deleted from the header label and the
        // identical literal parked on the drawer's interior
        // `VStack`; read to a `to:` bound it passed green again
        // with one `.overlay { }` truncating the run before the
        // literal it watches (guard-prover, 2026-08-26).
        let labelRun = try body(of: "}label:", in: file)
        #expect(
            labelRun.contains(
                ".font(SettingsDrawerHeader.tier.weight(.semibold))"
            ),
            Comment(
                rawValue:
                    "the header label lost the one tier — "
                    + "\(labelRun)"
            )
        )
        // ONE tier, and it is the ONLY font here. A positive
        // needle for the tier proves nothing on its own: keeping
        // it and APPENDING `.font(.title3…)` passed green with
        // the header drawing 15 pt and the summary 10 — maximal
        // divergence, under a guard whose commit message said
        // the two could no longer drift apart (guard-prover,
        // 2026-08-26). SwiftUI draws the last one, so counting
        // is the invariant; a needle is not.
        #expect(
            fonts(in: labelRun) == 1,
            Comment(
                rawValue:
                    "the header label carries "
                    + "\(fonts(in: labelRun)) fonts; the tier "
                    + "must be its only one — \(labelRun)"
            )
        )
    }

    @Test("the summary is drawn once, and only while shut")
    func theSummaryTierLivesInTheStyle() throws {
        let style = try squashed(Self.styleFile)
        let summaryRun = try body(
            of: "privatevarsummaryText:someView",
            in: style
        )
        #expect(
            summaryRun.contains(".font(SettingsDrawerHeader.tier)"),
            "the summary spells a size instead of the tier"
        )
        // The other half of the anti-drift pair — see the
        // header's clause for why a needle alone is not it.
        #expect(
            fonts(in: summaryRun) == 1,
            Comment(
                rawValue:
                    "the summary carries \(fonts(in: summaryRun))"
                    + " fonts; the tier must be its only one — "
                    + "\(summaryRun)"
            )
        )
        // Through a THEME token, never which one. That it
        // takes an ink from `SettingsTheme` is the rule
        // (gui.md); that the ink is `ink3` is a tuning the
        // owner moved twice in one afternoon, and a guard that
        // reds on tuning is a tax rather than a net.
        #expect(
            summaryRun.contains(".foregroundStyle(SettingsTheme."),
            "the summary paints outside the theme"
        )
        // Shut-only AND inside the button, in ONE clause bound
        // to its subject and its position. Read file-wide this
        // asserted only that the file MENTIONS the condition:
        // guard-prover left `summaryText` ungated and rewrote
        // `makeBody`'s own content gate as the semantically
        // identical `if !isExpanded { EmptyView() } else { … }`
        // — ten tests green with the summary drawn while the
        // drawer stood open (2026-08-26).
        let labelRun = try run(
            in: style,
            from: "Spacer(minLength:0)",
            to: ".contentShape("
        )
        #expect(
            labelRun.contains(
                "if!configuration.isExpanded{summaryText}"
            ),
            Comment(
                rawValue:
                    "the summary left the button's label, or "
                    + "stopped being shut-only — \(labelRun)"
            )
        )
    }

}
