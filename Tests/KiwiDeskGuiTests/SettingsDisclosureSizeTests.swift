import Foundation
import Testing

/// What a drawer header is DRAWN at (#1021), as against
/// `SettingsDisclosureHeaderTests`, which owns what it is: a
/// full-row button, an accessory beside it, its state in words.
///
/// Split because the size clauses took that suite past the
/// 350-line ceiling, and because they watch a different thing —
/// these two reds when the header's tier goes back to being a
/// call-site decision, or when the indicator pins a size of its
/// own instead of inheriting the header's.
@Suite("Settings drawer header size")
struct SettingsDisclosureSizeTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Source with whitespace squashed, so a needle cannot be
    /// broken by a reflow.
    private func squashed(_ path: String) throws -> String {
        let text = try String(
            contentsOf: root.appendingPathComponent(path),
            encoding: .utf8
        )
        return text.split(separator: "\n")
            .map { $0.split(separator: "//", maxSplits: 1)[0] }
            .joined()
            .filter { !$0.isWhitespace }
    }

    private static let styleFile =
        "Sources/KiwiDesk/Settings/Components/Common/"
        + "SettingsDisclosureStyle.swift"

    @Test("the indicator is sized by the header it marks")
    func chevronInheritsTheHeaderFont() throws {
        let style = try squashed(Self.styleFile)
        // PROPORTIONAL, not a size of its own (#1021). The
        // chevron takes no `.font`, so it inherits the header's
        // — which is what #956 claimed and did not do: it
        // replaced the native triangle for being drawn at the
        // system's small size, then pinned the replacement at
        // `.footnote`, the smallest step on the ramp. A `.font(`
        // anywhere in the chevron's run is that regression,
        // whatever size it names.
        //
        // A SCALE STEP is the other half, and the one that
        // shipped: `.imageScale(.large)` on top of the
        // inheritance drew the indicator larger than the title
        // it marks, which is the heavy header the owner read
        // back (2026-08-26). Weight is the only step it takes.
        // The run ends at the FUNCTION's closing brace, never
        // at a modifier name. An anchor like
        // `.accessibilityHidden(true)` bounds the run above
        // itself, so a scale step appended on the next line is
        // still the chevron's own chain, still the defect this
        // clause names, and invisible — proven green
        // (guard-prover, 2026-08-26). The body carries no
        // closure, so the first `}` after the image IS the
        // function's.
        let chevronRun = try run(
            in: style,
            from: "Image(systemName:\"chevron.right\")",
            to: "}"
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

    /// The modifier run of one expression, so a needle cannot be
    /// satisfied by a `.font(` belonging to some other view in
    /// the same file.
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
        let file = try squashed(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsDisclosure.swift"
        )
        // One shape, not two: `squashed` joins every newline
        // away, so the `caseinline\n` disjunct this carried
        // could never match and read as coverage it did not
        // have. It stays as the non-empty-input check.
        #expect(file.contains("caseinline"))
        #expect(
            !file.contains("caseinline(font:"),
            "the chrome carries a font payload again"
        )
        #expect(
            !file.contains("labelFont"),
            "the per-chrome label font is back"
        )
        // Scoped to the LABEL's own run, for the reason the
        // sibling clause is: read against the whole file, this
        // passed green when the `.font` was deleted from the
        // header label and the identical literal parked on the
        // drawer's interior `VStack` — the header then draws at
        // whatever it inherits, which IS the call-site-decision
        // state this test is named for (guard-prover,
        // 2026-08-26).
        let labelRun = try run(
            in: file,
            from: "Text(control.text)",
            to: "}"
        )
        #expect(
            labelRun.contains(".font(.callout.weight(.semibold))"),
            Comment(
                rawValue:
                    "the header label lost the one tier — "
                    + "\(labelRun)"
            )
        )
    }

    /// The drawer's SUMMARY — what it hides, stated beside the
    /// header while it is shut — is the header tier's own drift
    /// wearing a different slot (owner, 2026-08-26). Five call
    /// sites drew it by hand at `.font(.caption)`, 10 pt against
    /// a 12 pt header, and the fifth had also decided the
    /// shut-only rule differently from the other four. The slot
    /// now owns both, so a `.font(` inside an `accessory:`
    /// closure is the drift coming back.
    ///
    /// It scans the whole Settings tree rather than the five
    /// known files: the harm is a NEW call site re-deciding the
    /// tier, which a list of today's callers cannot see.
    @Test("no call site sizes what sits beside a header")
    func accessoryClosuresCarryNoFont() throws {
        let settings =
            root
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files =
            FileManager.default
            .enumerator(at: settings, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        #expect(!files.isEmpty, "the scan root moved")
        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for closure in accessoryClosures(in: text)
            where closure.contains(".font(") {
                offenders.append(file.lastPathComponent)
            }
        }
        #expect(
            offenders.isEmpty,
            Comment(
                rawValue:
                    "an accessory closure sizes its own text; "
                    + "pass `summary:` instead — "
                    + offenders.joined(separator: ", ")
            )
        )
    }

    /// Every `accessory: {` body in one file, brace-balanced so
    /// the scan stops at the closure's own end rather than at
    /// the first `}` it meets.
    private func accessoryClosures(in text: String) -> [String] {
        var bodies: [String] = []
        var search = text.startIndex..<text.endIndex
        while let open = text.range(
            of: "accessory: {",
            range: search
        ) {
            var depth = 1
            var index = open.upperBound
            while index < text.endIndex, depth > 0 {
                if text[index] == "{" { depth += 1 }
                if text[index] == "}" { depth -= 1 }
                index = text.index(after: index)
            }
            bodies.append(String(text[open.upperBound..<index]))
            search = index..<text.endIndex
        }
        return bodies
    }

    @Test("the summary is drawn once, and only while shut")
    func theSummaryTierLivesInTheStyle() throws {
        let style = try squashed(Self.styleFile)
        let summaryRun = try run(
            in: style,
            from: "Text(summary)",
            to: "}"
        )
        #expect(summaryRun.contains(".font(.callout)"))
        #expect(
            summaryRun.contains(
                ".foregroundStyle(SettingsTheme.ink3)"
            ),
            "the summary is description, not an affordance"
        )
        // Shut-only, in the style rather than at a call site —
        // expanded, the rows below say it in full.
        #expect(
            style.contains("if!configuration.isExpanded{"),
            "the summary shows while the drawer is open"
        )
    }
}
