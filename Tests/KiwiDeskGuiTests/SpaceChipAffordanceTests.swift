import Foundation
import Testing

@testable import KiwiDesk

/// What makes a Space chip read as something you can pick up
/// (#1240), as three shapes rather than three numbers.
///
/// The Monitors picture says *Drag a Space onto the display it
/// belongs to* in words, and the chips said nothing back. Paint
/// alone cannot say "draggable", so what the change buys is
/// narrower and has to be guarded as such: the drag SOURCES are
/// the only things on the page wearing a closed edge, hover
/// confirms the hit area, and the lifted chip does not show a
/// remove button. Each clause below is the decision, not the
/// value it currently resolves to — retuning an alpha leaves
/// them green, undoing a decision reds them.
@Suite("Space chip drag affordance")
struct SpaceChipAffordanceTests {
    private static let monitors =
        "Sources/KiwiDesk/Settings/Components/Monitors"

    private func squashed(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.monitors)
            .appendingPathComponent(file)
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        #expect(
            source.count > 200,
            Comment(
                rawValue: "\(file) read empty — proves nothing"
            )
        )
        return source.split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// `declaration`'s own balanced body — the shared scoper,
    /// which every evasion `guard-prover` found in this suite's
    /// first draft (2026-09-06) was the absence of: a needle
    /// read against the FILE is satisfied, or broken, by a
    /// neighbour.
    private func declarationBody(
        _ declaration: String,
        in source: String
    ) throws -> String {
        try #require(
            SourceScan.declarationBody(
                after: declaration,
                in: source
            ),
            Comment(rawValue: "no `\(declaration)` to scan")
        )
    }

    /// The edge is one weight for every kind.
    ///
    /// A chip's KIND is carried by fill-vs-outline and its glyph;
    /// the edge carries "this is a piece, not printed ink", which
    /// is the same for all three. The pinned chip used to draw
    /// the FAINTER edge at half a point — a half-pixel at 1x, so
    /// on exactly the external screens this page is about its
    /// perimeter could vanish.
    ///
    /// What it TRADES: only the INLINE `lineWidth: kind …`
    /// spelling reds. A width behind a computed property — the
    /// shape the two alphas themselves took — passes, because a
    /// scan cannot follow it. The alphas are guarded by value
    /// instead, in `SpaceChipTintTests`; a width moved there
    /// would owe the same.
    @Test("every edge draws at one literal weight")
    func edgeWeightIsUniform() throws {
        let source = try squashed("SpaceAssignmentChip.swift")
        let text = Array(source)
        let marker = Array("Capsule().strokeBorder")
        var widths: [String] = []
        var index = 0
        while index + marker.count <= text.count {
            guard Array(text[index..<(index + marker.count)]) == marker
            else {
                index += 1
                continue
            }
            var cursor = index + marker.count
            let args = try #require(
                SourceScan.balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
            )
            let key = "lineWidth:"
            let at = try #require(
                args.range(of: key),
                Comment(rawValue: "a stroke with no width: \(args)")
            )
            widths.append(
                String(
                    args[at.upperBound...]
                        .prefix { $0 != "," }
                )
            )
            index = cursor
        }
        #expect(
            !widths.isEmpty,
            Comment(
                rawValue:
                    "the chip draws no closed edge at all — the "
                    + "rest half of the affordance"
            )
        )
        // EVERY stroke, and each width a bare literal: an
        // expression is how a kind gets back in, whether it
        // spells `kind`, hides behind a computed property or
        // wears a pair of parentheses — all three of which
        // `guard-prover` walked past a `lineWidth:kind` needle
        // with (2026-09-06). A second overlay draws on TOP of
        // the first, so one stroke is not the population.
        for width in widths {
            #expect(
                Double(width) != nil,
                Comment(
                    rawValue:
                        "an edge width is the expression "
                        + "`\(width)` rather than a constant — a "
                        + "kind-varying weight draws a sub-point "
                        + "perimeter that vanishes at 1x"
                )
            )
        }
        #expect(
            Set(widths).count == 1,
            Comment(
                rawValue:
                    "the chip draws edges at \(Set(widths)) — one "
                    + "weight for every kind, the kind moving the "
                    + "alpha instead"
            )
        )
    }

    /// The `+n` marker is not dressed as a chip.
    ///
    /// It draws a popover; it is not a drag source. It used to
    /// wear the pinned chip's rest fill byte for byte, so the
    /// page's paint said "chip" for two different kinds of
    /// thing and any rest cue the chips gained was diluted by a
    /// neighbour mimicking it. Routed through the shared
    /// adaptive chip instead — the seam, never which alpha.
    @Test("the +n marker draws no tint of its own")
    func overflowMarkerIsNotAChip() throws {
        for file in ["DisplayCard.swift", "FollowsMainTray.swift"] {
            let body = try declarationBody(
                "privatefuncoverflowChip",
                in: try squashed(file)
            )
            // CONTIGUOUS, and `padding:0` is the load-bearing
            // half: the default 4 widens the marker past the
            // column `MonitorCardChips.markerWidth` reserves,
            // and that suite's needle stays green through it
            // because it reads the inner frame.
            #expect(
                body.contains(
                    ".hoverHighlight(cornerRadius:MonitorCardChips"
                        + ".chipHeight/2,padding:0)"
                ),
                Comment(
                    rawValue:
                        "\(file)'s `+n` marker no longer takes "
                        + "the shared adaptive chip at the "
                        + "padding its reserved column allows"
                )
            )
            // The invariant is that the marker wears NO tint —
            // not that one spelling of a tinted capsule is
            // absent. `guard-prover` respelled the same costume
            // as `.background(_:in:)` and walked past a
            // `Capsule().fill(.tint.opacity(` needle, while an
            // unrelated capsule elsewhere in the file reported
            // the marker for a fill it never drew (2026-09-06).
            #expect(
                !body.contains(".tint"),
                Comment(
                    rawValue:
                        "\(file)'s `+n` marker draws a tint — "
                        + "that is the drag source's costume, and "
                        + "this marker opens a popover"
                )
            )
        }
    }

    /// The drop wash is a GROUND, so it goes behind the chips.
    ///
    /// It exists because the selected card already owns the
    /// border channel, so drop-targeting needed one of its own —
    /// that ruling stands. But as an `.overlay` it painted over
    /// the assignments being dragged onto, and the automatic
    /// chip has no fill to survive it, so the card dimmed
    /// exactly what the drag is about (#1240, owner
    /// 2026-09-06). Layer, not alpha: retuning the wash leaves
    /// this green.
    @Test("the drop wash is drawn behind the chips")
    func dropWashSitsUnderTheContent() throws {
        let source = try squashed("DisplayCard.swift")
        #expect(
            source.contains(".background(dropWash)"),
            Comment(
                rawValue:
                    "the drop wash is no longer a background — "
                    + "as an overlay it dims the chips the drag "
                    + "is about"
            )
        )
        #expect(
            !source.contains(".overlay(dropWash)"),
            Comment(
                rawValue:
                    "the drop wash is an overlay again, so it "
                    + "paints over the card's own chips"
            )
        )
    }

    /// The lifted chip carries no clear button.
    ///
    /// `.draggable` snapshots the view it is applied to. With
    /// the badge inside that view the drag preview shows an ⓧ,
    /// which reads as "release to remove" — the opposite of what
    /// releasing does. So the badge is applied OUTSIDE the
    /// dragged view and the preview is stated explicitly; an
    /// argument-less `.draggable` is the defect returning.
    @Test("the drag preview is stated and excludes the badge")
    func dragPreviewExcludesTheClearBadge() throws {
        let source = try squashed("SpaceAssignmentChip.swift")
        #expect(
            source.contains(
                ".draggable(DraggableSpace(raw:space.raw)){capsule}"
            ),
            Comment(
                rawValue:
                    "the chip no longer states its drag "
                    + "preview — the default snapshots whatever "
                    + "the badge is attached to"
            )
        )
        // Asked of `body`, not of `capsule`: an indirection
        // between them (`capsule` returning a view that carries
        // the badge) leaves `capsule`'s own text clean while the
        // ⓧ is back in the preview, which is how `guard-prover`
        // beat the first shape of this clause (2026-09-06). The
        // badge has exactly one home, and it is the chain the
        // preview is NOT taken from.
        let body = try declarationBody("varbody:someView", in: source)
        #expect(
            body.contains(
                ".overlay(alignment:.topTrailing){clearBadge}"
            ),
            Comment(
                rawValue:
                    "the clear badge is no longer applied in "
                    + "`body` — wherever it went, the dragged "
                    + "view may now carry it"
            )
        )
        #expect(
            !(try declarationBody("privatevarcapsule:someView", in: source))
                .contains("clearBadge"),
            Comment(
                rawValue:
                    "the clear badge is inside `capsule` again, "
                    + "so the drag preview carries it"
            )
        )
    }

    /// `declaration`'s own balanced body, so a clause asks the
    /// subject rather than the file.
    ///
    /// Every evasion `guard-prover` found in the first draft
    /// (2026-09-06) was the same fault: a file-scoped needle
    /// satisfied — or broken — by a neighbour. A tinted capsule
    /// somewhere else reported the marker; a hover chip on the
}
