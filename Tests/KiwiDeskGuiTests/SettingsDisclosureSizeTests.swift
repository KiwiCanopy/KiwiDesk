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
        let chevronRun = try run(
            in: style,
            from: "Image(systemName:\"chevron.right\")",
            to: ".accessibilityHidden(true)"
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
        #expect(file.contains("caseinline\n") || file.contains("caseinline"))
        #expect(
            !file.contains("caseinline(font:"),
            "the chrome carries a font payload again"
        )
        #expect(
            !file.contains("labelFont"),
            "the per-chrome label font is back"
        )
        #expect(
            file.contains(".font(.callout.weight(.semibold))"),
            "both chromes draw the one header tier"
        )
    }
}
