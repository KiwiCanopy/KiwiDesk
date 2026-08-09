import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the Scrolling preview's words are allowed to say (#753).
///
/// Split from `LayoutSchematicScrollingTests` before that file
/// reached the ceiling, and they fail apart anyway: that suite
/// holds the drawing, this one holds the sentence beside it.
///
/// **These assertions read no English and cannot say which locale
/// they DO read.** `L()` resolves through the shipped catalogs and
/// several GUI suites call `LocalizationManager.shared.select(…)`
/// concurrently, so what these strings are in is whatever a
/// concurrent suite last set — the reason
/// `CrossReferenceRowSlotTests` gives for not pinning one here
/// either. Coverage survives that: every claim below is a
/// comparison between two rendered strings, or a search for a
/// term rendered from the same catalog.
///
/// `@MainActor` because the prose producers are members of a
/// `View`: off the main actor the first read traps in the
/// concurrency runtime rather than failing an expectation.
@Suite("Layout preview scrolling caption")
@MainActor
struct LayoutSchematicCaptionTests {
    /// The words switch on the anchor, because the anchor is the
    /// only thing `follow` changes: its frame is `center`'s to the
    /// pixel (`LayoutSchematicScrollingTests`), so a caption
    /// shared with `center` makes selecting Follow a no-op on
    /// screen — and made VoiceOver assert Follow's pan over a tile
    /// drawn with Center selected.
    @Test("Follow says something Center does not")
    func theAnchorReachesTheWords() {
        let follow = scrolling(anchor: .follow)
        let centre = scrolling(anchor: .center)
        #expect(follow.caption != centre.caption)
        #expect(follow.axLabel != centre.axLabel)
        // And the anchored three are not carrying a sentence about
        // a fourth: Follow's own name appears in Follow's words
        // and nowhere else. Read through the picker's own key, so
        // this holds in whatever locale the run is in — and so a
        // translation that reuses the term for the anchored
        // caption reds, which is the point rather than a
        // side effect.
        let name = L("scroll_grid.anchor.follow", "Follow")
        #expect(follow.caption.contains(name))
        for anchor in [
            ScrollingParams.Anchor.center, .start, .end,
        ] {
            let other = scrolling(anchor: anchor)
            #expect(!other.caption.contains(name))
            #expect(!other.axLabel.contains(name))
        }
    }

    /// The caption promises a `+` only where one is drawn.
    ///
    /// The row runs several canvases wide at most counts, so the
    /// incoming slot is often clipped away entirely — at the
    /// default five windows with New window ▸ Last it already is.
    /// The clause is a condition on the row rather than on the
    /// pixels, since the caption cannot read the canvas, so what
    /// is owed is the IMPLICATION: wherever it is claimed, the
    /// drawing's own `onCanvas` agrees, at every width a pane can
    /// be. Both directions of the pair are counted, so a clause
    /// that never fires cannot pass for a correct one.
    @Test("the + clause is claimed only where the + is drawn")
    func theInsertionClauseMatchesTheDrawing() {
        var claimed = 0
        var withheld = 0
        for anchor in ScrollingParams.Anchor.allCases {
            for placement in placements {
                for size in slotSizes {
                    for count in LayoutSchematic.windowCountRange {
                        let schematic = scrolling(
                            anchor: anchor,
                            placement: placement,
                            slotSize: size,
                            windows: count
                        )
                        guard schematic.drawsInsertionMark else {
                            withheld += 1
                            continue
                        }
                        claimed += 1
                        for along in widths {
                            let m = schematic.metrics(along: along)
                            #expect(
                                schematic.onCanvas(
                                    m.newIdx,
                                    m,
                                    along: along
                                ),
                                Comment(
                                    rawValue:
                                        "\(anchor)/\(placement) "
                                        + "at \(count), \(along) "
                                        + "pt: + off the canvas"
                                )
                            )
                        }
                    }
                }
            }
        }
        #expect(claimed > 0)
        #expect(withheld > 0)
    }

    /// And the clause is what the claim renders — the sentence is
    /// in the caption exactly when the mark is on the frame, with
    /// no dangling space where it went.
    @Test("the caption carries the clause it claims")
    func theClauseIsRendered() {
        let beside = scrolling(placement: .afterFocused)
        let far = scrolling(
            placement: .last,
            windows: LayoutSchematic.windowCountRange.upperBound
        )
        #expect(beside.drawsInsertionMark)
        #expect(!far.drawsInsertionMark)
        #expect(!beside.insertionClause.isEmpty)
        #expect(far.insertionClause.isEmpty)
        #expect(beside.caption.contains(beside.insertionClause))
        #expect(far.caption.count < beside.caption.count)
        #expect(!far.caption.hasSuffix(" "))
    }

    // MARK: - Fixtures

    private let placements: [SpawnPlacement] = [
        .first, .last, .beforeFocused, .afterFocused,
    ]

    /// The slot sizes the three `ScrollSize` arms can produce,
    /// including both ends of the points ramp: the 14 pt floor and
    /// the widest slot are where a width-free claim would break if
    /// it were going to.
    private let slotSizes: [ScrollSize] = [
        .auto, .fraction(0.12), .fraction(0.92), .points(100),
        .points(1200),
    ]

    /// The along-axis lengths a panel can take, from a pane
    /// squeezed beside the override rows at the 720 pt minimum
    /// window to a full-screen one.
    private let widths: [CGFloat] = [60, 120, 228, 400, 900, 1600]

    /// `.panel` throughout: the caption is the subject, and a
    /// thumbnail suppresses it.
    private func scrolling(
        anchor: ScrollingParams.Anchor = .center,
        placement: SpawnPlacement = .last,
        slotSize: ScrollSize = .auto,
        windows: Int = LayoutSchematic.defaultWindowCount
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: .horizontal,
            anchor: anchor,
            slotSize: slotSize,
            placement: placement,
            windows: windows,
            scale: .panel
        )
    }
}
