import Foundation
import Testing

@testable import KiwiDesk

/// The row axis has ONE application site (#678 turn 17a).
///
/// Every labelled row used to frame its own label to
/// `settingsLabelColumn`, which was harmless while there was
/// one arrangement and is not now: a row that keeps framing its
/// own label keeps the shared column at 820 pt, where the
/// column leaves a segmented control ~90 pt and the control
/// wraps or clips — exactly what 17a's "controls never" is
/// about. The failure is invisible in every other guard,
/// because such a row still compiles, still aligns at 1440 and
/// still reads correctly in review.
///
/// Stated residue: this scans the label COLUMN's application.
/// A row that lays its label out some third way — a `Grid`, a
/// hand-rolled `HStack` with a `Spacer` — is outside what a
/// needle can see, and belongs to review.
@Suite("Settings row shape")
struct SettingsRowShapeTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// Files that may frame a label to a fixed column of their
    /// own, and why. The one copy of who may.
    ///
    /// `ColorField` is here on the standing exception rather
    /// than as an oversight: the colour fields live in their
    /// own two-column grid, deliberately NOT on the shared row
    /// axis (`SettingsMetrics.colorLabelColumn`), so they are
    /// not rows this shape governs.
    ///
    /// The shape's own site is deliberately NOT in this map:
    /// it frames CONDITIONALLY (`stacked ? nil : labelColumn`)
    /// and so matches none of the needles below, which is what
    /// makes an unconditional frame the thing this scan looks
    /// for. That site is pinned by `shapeSwapsLayout` instead.
    private static let allowed: [String: String] = [
        "ColorField.swift":
            "the colour grid's own axis, never the row axis"
    ]

    @Test("only the shape frames a label to the column")
    func oneLabelColumnSite() throws {
        let root = Self.root.appendingPathComponent(
            "Sources/KiwiDesk"
        )
        var framing: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .filter { !$0.isWhitespace }
            scanned += 1
            // Every spelling of "frame a label to a settings
            // column". The override one was missing from the
            // first cut, and an inheriting override row was
            // hand-framing through it — the scan passed for not
            // knowing the word (code review, 2026-08-11). A new
            // column constant joins this list with its site.
            let needles = [
                ".frame(width:labelColumn",
                ".frame(width:SettingsMetrics.labelColumn",
                ".frame(width:overrideLabelColumn",
                ".frame(width:SettingsMetrics.overrideLabelColumn",
                ".frame(width:SettingsMetrics.colorLabelColumn",
                ".frame(width:labelWidth",
            ]
            if needles.contains(where: source.contains) {
                framing.append(file.lastPathComponent)
            }
        }
        #expect(scanned > 50)
        #expect(
            Set(framing) == Set(Self.allowed.keys),
            Comment(
                rawValue:
                    "a row frames its own label column: "
                    + framing.sorted().joined(separator: ", ")
                    + " — route it through SettingsRowShape or "
                    + "argue the exemption in this suite's map"
            )
        )
    }

    /// The shape switches LAYOUT rather than swapping
    /// subtrees, and the label's column goes away entirely
    /// when it stacks. Both halves matter: an `if` here would
    /// tear the control down on every reflow (a menu closes, a
    /// field loses focus mid-drag), and a stacked label still
    /// framed to 210 pt would put the control under a label
    /// that no longer reaches it.
    @Test("the shape swaps the layout, not the subtree")
    func shapeSwapsLayout() throws {
        let source = try squashed(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsRowShape.swift"
        )
        #expect(source.contains("letstacked=width.stacksRows"))
        #expect(
            source.contains(
                "?AnyLayout(VStackLayout(alignment:.leading,"
                    + "spacing:4)):AnyLayout(HStackLayout())"
            )
        )
        #expect(
            source.contains(
                ".frame(width:stacked?nil:labelColumn,"
                    + "alignment:.leading)"
            )
        )
    }

    /// The shared row vocabulary goes through the shape. A
    /// row type that stops doing so keeps the wide arrangement
    /// at every width — and the row types are exactly where a
    /// new control gets added, so this is the list that rots.
    @Test("every shared row type takes the shape")
    func sharedRowsTakeTheShape() throws {
        let files = [
            "Components/Common/SettingsRows.swift",
            "Components/Common/SegmentedPicker.swift",
            "Components/Common/SlotSizeRows.swift",
            "Components/GapsAndBorders/GapsEditor.swift",
            // The override chrome's inheriting readout — it
            // framed its own label through the OVERRIDE column
            // and so matched none of the first cut's needles,
            // drawing the wide arrangement inside a list whose
            // live rows stacked (code review, 2026-08-11).
            "Components/Bars/AppBarOverrideControls.swift",
        ]
        for file in files {
            let source = try squashed(
                "Sources/KiwiDesk/Settings/" + file
            )
            #expect(
                source.contains("SettingsRowShape{"),
                Comment(
                    rawValue:
                        "\(file) no longer builds its rows "
                        + "through the shape"
                )
            )
        }
    }

    private func squashed(_ path: String) throws -> String {
        let url = Self.root.appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .filter { !$0.isWhitespace }
    }
}
