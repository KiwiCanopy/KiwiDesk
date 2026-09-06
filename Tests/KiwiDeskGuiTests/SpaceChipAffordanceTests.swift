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

    /// The edge is one weight for every kind.
    ///
    /// A chip's KIND is carried by fill-vs-outline and its glyph;
    /// the edge carries "this is a piece, not printed ink", which
    /// is the same for all three. The pinned chip used to draw
    /// the FAINTER edge at half a point — a half-pixel at 1x, so
    /// on exactly the external screens this page is about its
    /// perimeter could vanish. A `lineWidth` that varies by kind
    /// is that defect returning, whatever the number.
    @Test("the chip's edge weight does not vary by kind")
    func edgeWeightIsUniform() throws {
        let source = try squashed("SpaceAssignmentChip.swift")
        let stroke = try #require(
            source.range(of: "Capsule().strokeBorder("),
            Comment(
                rawValue:
                    "the chip no longer draws a closed edge — "
                    + "the rest half of the affordance"
            )
        )
        let tail = balanced(from: stroke.upperBound, in: source)
        #expect(
            !tail.contains("lineWidth:kind"),
            Comment(
                rawValue:
                    "the chip's edge weight varies by kind "
                    + "again (`\(tail)`) — the kind belongs in "
                    + "the alpha, and a sub-point edge "
                    + "disappears at 1x"
            )
        )
    }

    /// The argument list from `start` up to the paren that
    /// CLOSES it.
    ///
    /// A `prefix(while: != ")")` stops at the first `)`, which
    /// here belongs to the nested `.opacity(` — so the scan
    /// never reached `lineWidth:` and the clause above passed
    /// on a restored defect. Found by mutating it (2026-09-06);
    /// the depth count is what makes the needle reach its own
    /// argument.
    private func balanced(
        from start: String.Index,
        in source: String
    ) -> String {
        var depth = 1
        var out = ""
        for character in source[start...] {
            if character == "(" { depth += 1 }
            if character == ")" {
                depth -= 1
                if depth == 0 { break }
            }
            out.append(character)
        }
        return out
    }

    /// The `+n` marker is not dressed as a chip.
    ///
    /// It draws a popover; it is not a drag source. It used to
    /// wear the pinned chip's rest fill byte for byte, so the
    /// page's paint said "chip" for two different kinds of
    /// thing and any rest cue the chips gained was diluted by a
    /// neighbour mimicking it. Routed through the shared
    /// adaptive chip instead — the seam, never which alpha.
    @Test("the +n marker takes the shared chip, not the chip's")
    func overflowMarkerIsNotAChip() throws {
        for file in ["DisplayCard.swift", "FollowsMainTray.swift"] {
            let source = try squashed(file)
            #expect(
                source.contains(".hoverHighlight("),
                Comment(
                    rawValue:
                        "\(file)'s `+n` marker no longer takes "
                        + "the shared adaptive chip"
                )
            )
            #expect(
                !source.contains("Capsule().fill(.tint.opacity("),
                Comment(
                    rawValue:
                        "\(file) draws a tinted capsule fill "
                        + "again — that is the drag source's "
                        + "costume, and this marker is a button"
                )
            )
        }
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
        // …and the badge really is outside that view: inside
        // `capsule` the explicit preview would carry it anyway.
        let capsule = try #require(
            source.range(of: "privatevarcapsule:someView{")
        )
        let badge = try #require(
            source.range(of: "overlay(alignment:.topTrailing)")
        )
        #expect(
            badge.lowerBound < capsule.lowerBound,
            Comment(
                rawValue:
                    "the clear badge moved back inside the "
                    + "dragged view, so the preview carries it"
            )
        )
    }
}
