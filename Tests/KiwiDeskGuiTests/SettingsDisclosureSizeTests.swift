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
        #expect(chevronRun.contains(".fontWeight(.bold)"))
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
        // Scoped to the LABEL's own run: read against the whole
        // file this passed green when the `.font` was deleted
        // from the header label and the identical literal parked
        // on the drawer's interior `VStack` — the header then
        // draws at whatever it inherits, which IS the
        // call-site-decision state this test is named for
        // (guard-prover, 2026-08-26).
        let labelRun = try run(
            in: file,
            from: "Text(control.text)",
            to: "}"
        )
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
        // ONE tier, not two literals that happen to agree. The
        // title and the summary beside it were both `.callout`
        // in two different types with nothing tying them, so
        // retuning the header would have left the summary
        // behind — the drift #1021 ended at fifteen call sites,
        // back at two (architect review, 2026-08-26).
        #expect(
            !labelRun.contains(".font(.callout"),
            "the header spells a size instead of the tier"
        )
    }

    @Test("the summary is drawn once, and only while shut")
    func theSummaryTierLivesInTheStyle() throws {
        let style = try squashed(Self.styleFile)
        let summaryRun = try run(
            in: style,
            from: "Text(summary)",
            to: "}"
        )
        #expect(
            summaryRun.contains(".font(SettingsDrawerHeader.tier)"),
            "the summary spells a size instead of the tier"
        )
        #expect(
            summaryRun.contains(
                ".foregroundStyle(SettingsTheme.ink3)"
            ),
            "the summary is description, not an affordance"
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

    /// The drawer's SUMMARY is the header tier's own drift
    /// wearing a different slot (owner, 2026-08-26). Five call
    /// sites drew it by hand, and four of the five wrapped their
    /// own shut-only `if` while the fifth did not — so the rule
    /// was a call-site decision too. The slot now owns both.
    ///
    /// **It watches `Text(`, not `.font(`.** Sizing was one
    /// spelling of the violation and not the worst:
    /// `accessory: { Text(x).foregroundStyle(.secondary) }`
    /// carries no font, and because the accessory is a SIBLING
    /// of the button it then inherits body 13 pt — LARGER than
    /// the 12 pt header beside it, which is worse than the five
    /// sites this replaced (architect review, 2026-08-26). That
    /// slot's purpose is a control; `DesktopsGroup`'s
    /// `HelpButton` is the only legitimate shape in the tree.
    ///
    /// **What it does not reach**, so nobody reads its green as
    /// more than it is (guard-prover, 2026-08-26): a font
    /// applied to the enclosing `SettingsDisclosure(…)`
    /// expression, which propagates into the accessory through
    /// the environment; an accessory body extracted to a
    /// computed property, which the 350-line ceiling makes an
    /// ordinary move; and a hand-drawn summary beside a
    /// `SettingsDisclosure(` that simply took no `summary:`.
    @Test("no call site draws what sits beside a header")
    func accessoryClosuresCarryNoText() throws {
        let files = try SourceScan.swiftSources(under: settingsRoot)
        #expect(!files.isEmpty, "the scan root moved")
        var offenders: [String] = []
        var closures = 0
        for file in files {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for body in accessoryClosures(in: text) {
                closures += 1
                if body.contains("Text(") {
                    offenders.append(file.lastPathComponent)
                }
            }
        }
        // The collection that MATTERS is the closures, not the
        // files: a rename of the `accessory:` label would leave
        // this scanning hundreds of files for zero closures and
        // passing — matched nothing, and therefore green
        // (guard-prover, 2026-08-26).
        #expect(closures >= 2, "no accessory closure was found")
        #expect(
            offenders.isEmpty,
            Comment(
                rawValue:
                    "an accessory closure draws its own text; "
                    + "pass `summary:` instead — "
                    + offenders.joined(separator: ", ")
            )
        )
    }

    /// Every `accessory:` closure body in one file, through
    /// `SourceScan.balanced` — which also skips string literals,
    /// where a hand-rolled counter would miscount braces.
    private func accessoryClosures(in text: String) -> [String] {
        let characters = Array(text)
        var bodies: [String] = []
        var searched = text.startIndex
        while let label = text.range(
            of: "accessory:",
            range: searched..<text.endIndex
        ) {
            var cursor = text.distance(
                from: text.startIndex,
                to: label.upperBound
            )
            if let body = SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            ) {
                bodies.append(body)
            }
            searched = label.upperBound
        }
        return bodies
    }
}
